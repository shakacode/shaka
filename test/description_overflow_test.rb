# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'handoff_helper'
require 'shaka/publication/publication'

# Shared fixtures for the overflow description tests. Kept out of the test class for its length.
module DescriptionOverflowExamples
  HEAD = 'a' * 40
  OLD = 'b' * 40
  OPEN = Shaka::Publishing::OPEN_MARK
  CLOSE = Shaka::Publishing::CLOSE_MARK
  URL = 'https://github.com/shakacode/shaka/pull/42#issuecomment-99'

  def moved(summary, text, timeline: nil)
    rendered = inflate(description(timeline:), summary, text)
    refute_operator Shaka::DescriptionOverflow.merged_length(rendered, @pull), :<=, 65_536
    body, package = Shaka::DescriptionOverflow.prepare(rendered, @pull)
    [body, package.fetch('comment')]
  end

  def assert_moved(body, comment, section, link)
    assert_operator Shaka::DescriptionOverflow.merged_length(body, @pull), :<=, 65_536
    refute_includes body, section
    assert_includes body, link
    assert_includes body, "<!-- shaka:overflow-active #{HEAD} -->"
    assert_includes comment, section
    assert_includes comment, "<!-- shaka:usage-overflow #{HEAD} -->"
    assert_usage_copy body, comment
  end

  def assert_usage_copy(body, comment)
    assert_includes comment, '<!-- shaka:usage '
    assert_includes body, '<!-- shaka:usage '
  end

  def description(note: 'Native usage is PARTIAL.', timeline: nil)
    body, package = Shaka::DescriptionOverflow.prepare(render(handoff_content(note), timeline:), @pull)
    assert_nil package, 'the fixture description itself must fit'
    body
  end

  def render(content, timeline: nil)
    Shaka::Publication.new(content, description: true, pull: @pull, timeline:)
                      .render(%i[steps intent_verification sections evidence metrics wip credit], lead: %i[lead])
  end

  def timeline
    opened = Time.utc(2026, 9, 1)
    { 'opened' => opened, 'merged' => opened + 3600, 'labels' => [], 'steps' => [] }
  end

  def head = { 'sha' => HEAD, 'repo' => { 'full_name' => 'shakacode/shaka' } }

  def handoff_content(note)
    record = USAGE_RECORD.merge('columns' => [column], 'note' => note)
    { 'identity' => HandoffFixtures::IDENTITY, 'summary' => 'A summary.', 'table' => HandoffFixtures::TABLE,
      'deployment' => 'none', 'steps_besides_merging' => 'none', 'intent' => INTENT,
      'verification' => VERIFICATION, 'provenance' => HandoffFixtures::PROVENANCE,
      'usage' => { 'note' => note, 'records' => [record] }, 'details' => [], 'wip' => HandoffFixtures::WIP }
  end

  def column = HandoffFixtures::USAGE_COLUMN

  # Grows the hidden record without also growing the visible note, so pricing and timings
  # cannot bring the body back under the limit.
  def pad_usage_records(body)
    body.sub('<!-- shaka:usage:end -->', "#{'x' * 62_000}\n<!-- shaka:usage:end -->")
  end

  def inflate(body, summary, text)
    body.sub(%r{(<details>\n<summary>#{Regexp.escape(summary)}[^<]*</summary>\n\n)}) do
      "#{Regexp.last_match(1)}#{text}\n\n"
    end
  end

  def wrap(body) = "#{OPEN}\n#{body}#{CLOSE}"

  def comment_github(comment)
    FakeOverflowGitHub.new(comment: "#{Shaka::DescriptionOverflow::MARK}\n#{comment}")
  end

  def restore_padded
    body, package = Shaka::DescriptionOverflow.prepare(pad_usage_records(description), @pull)
    Shaka::DescriptionOverflow.restore(comment_github(package.fetch('comment')),
                                       @pull.merge('body' => wrap(body)))
  end

  def handoff_for(sha)
    marker = "<!-- shaka:overflow-active #{sha} -->\n"
    body = HandoffFixtures.description.sub(CLOSE, "#{marker}#{CLOSE}")
    comment = HandoffFixtures.comment(9, "#{Shaka::DescriptionOverflow::MARK}\n<!-- shaka:usage-overflow #{sha} -->\n")
    HandoffHarnessHandoff.new.handoff(body:, comments: [comment])
  end
end

# A description that usage reports would push past GitHub's limit keeps those reports (#878).
class DescriptionOverflowTest < Minitest::Test
  include DescriptionOverflowExamples

  def setup
    @pull = { 'number' => 42, 'body' => '', 'head' => { 'sha' => HEAD } }
  end

  def test_a_description_under_the_limit_is_unchanged
    rendered = description

    body, package = Shaka::DescriptionOverflow.prepare(rendered, @pull)

    assert_nil package
    assert_equal rendered, body
    refute_includes body, 'shaka:overflow'
  end

  def test_pricing_notes_move_first_and_the_usage_markers_stay_in_the_comment
    body, comment = moved('How each report was measured and priced', 'Note. ' * 10_500)
    assert_moved body, comment, 'How each report was measured and priced',
                 'Per-report pricing notes are in [Usage and timing details for #42]'
  end

  def test_timings_move_when_pricing_notes_are_not_enough
    rendered = inflate(description(timeline:), 'Timings', 'Stretch. ' * 7_100)
    # Pricing notes are small; the timings section is what crosses the limit.
    body, package = Shaka::DescriptionOverflow.prepare(rendered, @pull)

    assert_operator Shaka::DescriptionOverflow.merged_length(body, @pull), :<=, 65_536
    refute_includes body, '<summary>Timings'
    assert_includes body, 'Timings are in [Usage and timing details for #42]'
    assert_includes package.fetch('comment'), '<summary>Timings'
    assert_includes body, '<!-- timeline-steps ' if rendered.include?('<!-- timeline-steps ')
  end

  def test_hidden_usage_records_move_when_the_description_is_still_too_long
    rendered = pad_usage_records(description)

    body, package = Shaka::DescriptionOverflow.prepare(rendered, @pull)

    assert_operator Shaka::DescriptionOverflow.merged_length(body, @pull), :<=, 65_536
    refute_includes body, '<!-- shaka:usage '
    assert_includes body, 'Earlier usage reports are in [Usage and timing details for #42]'
    assert_includes package.fetch('comment'), '<!-- shaka:usage '
    restored = Shaka::DescriptionOverflow.restore(comment_github(package.fetch('comment')),
                                                  @pull.merge('body' => wrap(body)))
    assert_includes restored, '<!-- shaka:usage '
  end

  def test_a_body_that_still_does_not_fit_is_refused
    rendered = "#{description}\n#{'x' * 70_000}\n"

    error = assert_raises(Shaka::Error) { Shaka::DescriptionOverflow.prepare(rendered, @pull) }

    assert_includes error.message, '65536'
  end

  def test_deliver_updates_the_same_comment_and_links_it
    body, package = Shaka::DescriptionOverflow.prepare(inflate(description(timeline:), 'Timings', 'Stretch. ' * 7_100),
                                                       @pull)
    @pull['shaka_overflow'] = package
    github = FakeOverflowGitHub.new

    linked = Shaka::DescriptionOverflow.deliver(github, @pull, body)

    assert_equal ['usage-timing-details'], github.keys
    assert_includes linked, URL
    refute_includes linked, Shaka::DescriptionOverflow::PLACEHOLDER
  end

  def test_the_next_publish_reads_a_moved_record_back_into_carry
    restored = restore_padded
    fresh = USAGE_RECORD.merge('responses' => ['later'], 'commits' => ['c' * 40], 'columns' => [column],
                               'note' => 'Later.')
    carried, = Shaka::UsageRecords.carry_from({ 'usage' => { 'note' => 'n', 'records' => [fresh] } },
                                              @pull.merge('body' => restored, 'head' => head, 'base' => head))

    assert_includes carried.dig('usage', 'carried'), '<!-- shaka:usage '
  end

  def test_handoff_owes_a_comment_that_does_not_match_the_head
    result = handoff_for(OLD)

    assert(result.fetch('owed').any? { |item| item.include?('does not match this head') })
  end

  def test_handoff_accepts_a_comment_for_the_current_head
    result = handoff_for(HandoffFixtures::HEAD)

    assert_empty result.fetch('owed')
    assert_includes result.fetch('status'), 'usage details'
  end
end

# The comment's later states: retired, read back, or refused when it would lose a record.
class DescriptionOverflowLifecycleTest < Minitest::Test
  include DescriptionOverflowExamples

  def setup
    @pull = { 'number' => 42, 'body' => '', 'head' => { 'sha' => HEAD } }
  end

  def test_a_description_that_fits_again_retires_the_comment_but_keeps_its_records
    shrunk = description
    active = "#{shrunk.rstrip}\n\n<!-- shaka:overflow-active #{HEAD} -->\n"

    body, package = Shaka::DescriptionOverflow.prepare(shrunk, @pull.merge('body' => wrap(active)))

    refute Shaka::DescriptionOverflow.moved?(body)
    refute_includes package.fetch('comment'), 'shaka:usage-overflow'
    assert_includes package.fetch('comment'), '<!-- shaka:usage '
    assert_nil Shaka::DescriptionOverflow.issue(body, package.fetch('comment'), HEAD)
  end

  def test_restore_puts_a_moved_timings_section_back_in_place_of_its_link
    rendered = inflate(description(timeline:), 'Timings', 'Stretch. ' * 7_100)
    body, package = Shaka::DescriptionOverflow.prepare(rendered, @pull)
    linked = body.gsub(Shaka::DescriptionOverflow::PLACEHOLDER, URL)

    restored = Shaka::DescriptionOverflow.restore(comment_github(package.fetch('comment')),
                                                  @pull.merge('body' => wrap(linked)))

    assert_includes restored, '<summary>Timings'
    refute_includes restored, 'Timings are in ['
  end

  def test_a_comment_that_cannot_keep_every_usage_record_is_refused
    rendered = inflate(description, 'How each report was measured and priced', 'Note. ' * 7_000)
    rendered = rendered.sub('<!-- shaka:usage:end -->', "#{'x' * 30_000}\n<!-- shaka:usage:end -->")

    error = assert_raises(Shaka::Error) { Shaka::DescriptionOverflow.prepare(rendered, @pull) }

    assert_equal Shaka::DescriptionOverflow::COMMENT_LIMIT, error.message
  end

  def test_an_overflow_without_a_head_is_refused
    rendered = inflate(description, 'How each report was measured and priced', 'Note. ' * 10_500)

    error = assert_raises(Shaka::Error) { Shaka::DescriptionOverflow.prepare(rendered, nil) }

    assert_includes error.message, '65536'
  end

  def test_a_details_comment_is_not_read_back_without_the_viewer_login
    comment = { 'body' => "#{Shaka::DescriptionOverflow::MARK}\n", 'user' => { 'login' => 'someone' } }

    refute Shaka::DescriptionOverflow.ours?(comment, nil)
    refute Shaka::DescriptionOverflow.ours?(comment, '')
  end
end

# Exposes the harness without turning this file's tests into handoff cases.
class HandoffHarnessHandoff
  include HandoffHarness
end

# Records the one reply a publish sends.
class FakeOverflowGitHub
  attr_reader :keys

  def initialize(comment: nil)
    @keys = []
    @comment = comment
  end

  def reply(body:, key:)
    @keys << key
    { 'id' => 99, 'html_url' => DescriptionOverflowTest::URL, 'body' => body }
  end

  def viewer_login = 'shaka-agent'
  def issue_comments = @comment ? [{ 'body' => @comment, 'user' => { 'login' => 'shaka-agent' } }] : []
end
