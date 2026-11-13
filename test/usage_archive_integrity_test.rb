# frozen_string_literal: true

require_relative 'description_usage_archive_test'

# Partial reference loss must stop the builder, even when another reference is intact.
class UsageArchiveIntegrityTest < Minitest::Test
  include UsageRecordsFixture

  def archived_pair
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    first = record('codex', 'First', commits: archive_commits(1800), responses: [])
    second = record('claude-code', 'Second', responses: ['second-response'], contribution: 'review')
    github.description(body: "#{first}\n#{second}\n")
    github
  end

  def assert_builder_refuses(github, damaged)
    github.stored['body'] = damaged
    uploads = github.comments.size
    assert_raises(Shaka::Error) do
      github.description { flunk 'A damaged archive reached the description builder.' }
    end
    assert_equal damaged, github.stored['body']
    assert_equal uploads, github.comments.size
  end
  private :assert_builder_refuses

  def test_a_missing_opener_cannot_hide_one_record_behind_an_intact_reference
    github = archived_pair
    damaged = github.stored['body'].sub(/^<!-- shaka:usage-archive [^\n]* -->\n/, '')
    assert_builder_refuses(github, damaged)
  end

  def test_removing_an_entire_reference_is_detected
    github = archived_pair
    damaged = github.stored['body'].sub(Shaka::UsageArchive::REFERENCES, '')
    assert_builder_refuses(github, damaged)
  end

  def test_an_unmatched_end_marker_is_refused
    github = archived_pair
    damaged = github.stored['body'].sub(Shaka::Publishing::CLOSE_MARK) do |mark|
      "#{Shaka::UsageArchive::END_MARK}\n#{mark}"
    end
    assert_builder_refuses(github, damaged)
  end

  def test_a_new_contribution_reuses_prior_archives_and_uploads_only_its_own_block
    github = archived_pair
    earlier = github.comments.keys
    append_contribution(github)
    assert_equal earlier.size + 1, github.comments.size
    assert_reused_archives(github, earlier)
    assert_record_count(github, 3)
  end

  def append_contribution(github)
    fresh = record('codex', 'Fresh', responses: ['fresh-response'], contribution: 'review', sources: ['fresh-source'])
    github.description do |pull|
      content, = Shaka::UsageRecords.carry_from(described(fresh), pull)
      "#{content.fetch('details').first.fetch('body')}\n"
    end
  end
  private :append_contribution

  def assert_reused_archives(github, earlier)
    refs = github.stored['body'].scan(Shaka::UsageArchive::REFERENCES).map { |json, _display| JSON.parse(json) }
    assert_equal 2, refs.map { |ref| ref['sha256'] }.uniq.size
    assert_empty earlier - refs.flat_map { |ref| ref['comments'] }
  end
  private :assert_reused_archives

  def assert_record_count(github, count)
    restored = Shaka::UsageArchive.new(github).expand(github.stored['body'])
    assert_equal count, Shaka::UsageRecords.parsed_blocks(restored).size
  end
  private :assert_record_count

  def test_removing_a_complete_archive_group_is_detected
    github = archived_pair
    append_contribution(github)
    body = github.stored['body']
    final = body.to_enum(:scan, Shaka::UsageArchive::REFERENCES).map { Regexp.last_match[0] }.last
    damaged = body.sub(final, '')
    assert_builder_refuses(github, damaged)
  end

  def test_an_edited_inventory_is_refused
    github = archived_pair
    damaged = github.stored['body'].sub(Shaka::UsageArchiveReferences::INVENTORY) do
      "#{Shaka::UsageArchiveReferences::INVENTORY_PREFIX}#{'0' * 64} -->\n"
    end
    assert_builder_refuses(github, damaged)
  end

  def test_archive_attribution_does_not_repeat_a_frozen_spend_total
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    entry = record('codex', 'Large', commits: archive_commits(1800), responses: [])
    github.description(body: "🤖 AGENT · UNKNOWN · UNKNOWN · UNKNOWN - AI spend: $99\n\n#{entry}\n")
    github.comments.each_value do |comment|
      assert_equal '🤖 AGENT · UNKNOWN · UNKNOWN · UNKNOWN', comment.fetch('body').lines.first.chomp
    end
  end

  def test_markdown_receives_the_compact_preview_before_a_large_archive_is_uploaded
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    github.define_singleton_method(:markdown) do |body|
      raise Shaka::Error, 'Markdown API refuses text over 400 KB.' if body.bytesize > 400 * 1024

      super(body)
    end
    entry = record('codex', 'Large accounting', commits: archive_commits(12_000), responses: [])
    github.description(body: "#{entry}\n")
    assert_operator github.stored['body'].length, :<=, 65_536
  end
end
