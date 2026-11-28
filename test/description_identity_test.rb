# frozen_string_literal: true

require_relative 'throughput_helper'
require_relative 'usage_archive_test'
require_relative 'canary_test'
require_relative 'description_usage_archive_test'

# A description's first line names only the known identity fields. The rest stay marked
# UNKNOWN under Missing values, and every reader of that line takes both shapes.
class DescriptionIdentityTest < Minitest::Test
  include ThroughputHelper

  NOTE = 'UNKNOWN provider, model, effort: Codex session unavailable or ambiguous.'
  KNOWN = '🤖 Codex · OpenAI · gpt-5.6-terra · low'
  FULL = '🤖 Codex · UNKNOWN · UNKNOWN · UNKNOWN'
  LABEL = '- **Writer identity:** the first line shows only the known fields. In full:'
  ENTRY = "#{LABEL} #{FULL}\n  #{NOTE}".freeze
  BOTH = %r{<summary>Missing values</summary>\n\n- \*\*Task start\*\* [^\n]+\n- \*\*Writer identity:\*\* }
  STARTED = { 'task_started_at' => START, 'ci_started_at' => PUSH }.freeze

  def test_unread_fields_leave_the_first_line_and_stay_marked_under_missing_values
    rendered = unread
    assert_equal "🤖 Codex - AI spend: $1.44\n", rendered.lines.first
    refute_includes rendered, "_#{NOTE}_"
    assert_operator rendered.index('<summary>🤙 Shaka details</summary>'), :<, rendered.index(ENTRY)
    assert_includes rendered, "<summary>Missing values</summary>\n\n#{ENTRY}\n"
  end

  def test_a_partly_read_identity_keeps_its_read_fields_in_order
    rendered = unread('provider' => 'OpenAI', 'effort' => 'high', note: nil)
    assert_equal "🤖 Codex · OpenAI · high - AI spend: $1.44\n", rendered.lines.first
    assert_includes rendered, "#{LABEL} 🤖 Codex · OpenAI · UNKNOWN · high\n"
  end

  def test_an_unread_agent_keeps_its_place_so_the_line_never_starts_with_another_field
    rendered = Shaka::Publication.description(content('$1.44').merge('identity' => { 'model' => 'gpt-test' }))
    assert_equal "🤖 UNKNOWN · gpt-test - AI spend: $1.44\n", rendered.lines.first
    assert_includes rendered, "#{LABEL} 🤖 UNKNOWN · UNKNOWN · gpt-test · UNKNOWN\n"
  end

  # An unread agent alone is still unread, so its note moves into the fold too.
  def test_an_unread_agent_with_every_other_field_read_moves_its_note_into_the_fold
    identity = { 'provider' => 'OpenAI', 'model' => 'gpt-test', 'effort' => 'low' }
    rendered = Shaka::Publication.description(content('$1.44').merge('identity' => identity, 'publisher_note' => NOTE))
    assert_equal "🤖 UNKNOWN · OpenAI · gpt-test · low - AI spend: $1.44\n", rendered.lines.first
    refute_includes rendered, "_#{NOTE}_"
    assert_includes rendered, "#{LABEL} 🤖 UNKNOWN · OpenAI · gpt-test · low\n  #{NOTE}\n"
  end

  def test_the_writer_entry_follows_the_task_start_entry_in_one_block
    rendered = Shaka::Publication.description(unread_content, nil, nil, nil, { 'opened' => START, 'labels' => [] })
    assert_match(BOTH, rendered)
    assert_equal 1, rendered.scan(Shaka::MissingValues::HEADING).size
  end

  def test_a_fully_read_identity_renders_as_before_with_or_without_a_note
    known = describe('$1.44', timeline: STARTED)
    assert_equal "#{KNOWN} - AI spend: $1.44\n", known.lines.first
    refute_match(/\A[^\n]+\n\n_/, known)
    refute_includes known, 'Writer identity'
    noted = Shaka::Publication.description(content('$1.44').merge('publisher_note' => 'Unverified.'))
    assert noted.start_with?("#{KNOWN} - AI spend: $1.44\n\n_Unverified._\n\n")
    refute_includes noted, 'Writer identity'
  end

  # AgentPost tells an agent's post from a person's by the four fields, so these keep every one.
  def test_comments_replies_and_walkthroughs_keep_all_four_fields_and_the_note_line
    opening = "#{FULL}\n\n_#{NOTE}_\n\n"
    walkthrough = Shaka::Publication.walkthrough(unread_content.merge('head' => HEAD))
    [Shaka::Publication.comment(unread_content), walkthrough].each do |post|
      assert post.start_with?(opening), post.lines.first
      assert Shaka::AgentPost.marked?(post)
    end
  end

  def test_watcher_updates_rewrite_the_spend_on_both_shapes_and_keep_the_fields
    { unread => '🤖 Codex', describe('$1.44', timeline: STARTED) => KNOWN }.each do |body, line|
      updated = Shaka::ThroughputStats.update(body, 'spend' => '$2.00', 't2' => READY.iso8601)
      assert_equal "#{line} - AI spend: $2.00\n", updated.lines.first
      assert_equal updated, Shaka::ThroughputStats.update(updated, 'spend' => '$2.00', 't2' => READY.iso8601)
      assert_equal "#{line} - AI spend: $3.00\n", Shaka::ThroughputStats.refresh_spend(updated, '$3.00').lines.first
    end
  end

  # The block's heading also tells a watcher a missing task start is explained; this entry must not change times.
  def test_a_block_holding_only_the_writer_entry_leaves_recorded_times_alone
    updated = Shaka::ThroughputStats.update(unread, 't2' => READY.iso8601)
    assert_includes updated, '**Estimated token costs:** $1.44 · ready in 1h 19m'
    assert_includes updated, 'Prompt to CI 38m · CI to ready 41m'
    assert_includes updated, ENTRY
  end

  def test_the_canary_reads_the_spend_from_both_shapes
    old = CanaryBodyTest::BODY
    short = old.sub('🤖 Codex · OpenAI · gpt-test · low', '🤖 Codex')
    refute_equal old, short
    [old, short].each do |body|
      assert_empty Shaka::Canary::BodyCheck.issues(body)
      assert_equal '$1.00', Shaka::Canary::Spend.from(body)
    end
    assert_empty Shaka::Canary::BodyCheck.issues(unread).grep(/stats line/)
    assert_equal '$1.44', Shaka::Canary::Spend.from(unread)
  end

  private

  def unread(...) = Shaka::Publication.description(unread_content(...), nil, nil, nil, timeline)

  def unread_content(note: NOTE, **fields)
    content('$1.44').merge('identity' => { 'agent' => 'Codex' }.merge(fields), 'publisher_note' => note).compact
  end

  def timeline = { 'opened' => START, 'labels' => [] }.merge(STARTED)
end

# A usage archive comment copies the description's writer, and an agent comment needs all four fields.
class DescriptionIdentityArchiveTest < Minitest::Test
  include UsageRecordsFixture

  LABEL = DescriptionIdentityTest::LABEL
  KNOWN = DescriptionIdentityTest::KNOWN
  FULL = DescriptionIdentityTest::FULL
  ENTRY = DescriptionIdentityTest::ENTRY

  # A caller without the content signs from the first line alone, so no other text in the body can pick the signature.
  # A short line does not say which fields it kept, so only its agent survives.
  def test_usage_archive_comments_carry_four_fields_from_both_shapes
    decoy = "#{LABEL} 🤖 Someone · else · entirely · here"
    { "🤖 Codex · OpenAI - AI spend: $1.44\n\n#{decoy}" => FULL, "#{KNOWN} - AI spend: $1.44" => KNOWN,
      "#{KNOWN}\n\n_Old note._" => KNOWN, "#{KNOWN} - AI spend: $1.44\n\n#{decoy}" => KNOWN }.each do |opening, writer|
      assert_signed(archived(opening), writer)
    end
  end

  # The description command passes the full line, so the body's text and a backtick in a field do not matter.
  def test_the_description_command_signs_archive_comments_with_the_identity_it_rendered
    identity = { 'agent' => 'Codex', 'model' => 'gpt`custom' }
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    writer = -> { Shaka::PublicationText.identity(identity) }
    github.description(writer:) { "🤖 Codex · gpt`custom - AI spend: $1.44\n\n#{oversized_records}\n" }
    assert_operator github.stored['body'].length, :<=, 65_536
    assert_signed(github.comments.values.map { it.fetch('body') }, '🤖 Codex · UNKNOWN · gpt`custom · UNKNOWN')
  end

  private

  def assert_signed(bodies, writer)
    refute_empty bodies
    assert_equal [writer], bodies.map { it.lines.first.chomp }.uniq
    assert(bodies.all? { Shaka::AgentPost.marked?(it) })
  end

  def archived(opening)
    github = UsageArchiveTest::Comments.new
    Shaka::UsageArchive.new(github).prepare(oversized.sub("\nS\n", "\n#{opening}\n")).publish
    github.comments.each_value.map { it.fetch('body') }
  end

  def oversized_records = record('codex', 'kept', responses: Array.new(6000) { |i| "response-#{i}" })
  def oversized = existing(oversized_records)
end
