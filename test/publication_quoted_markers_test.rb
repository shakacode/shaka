# frozen_string_literal: true

require_relative 'publication_test'
require_relative 'github_helper'
require_relative 'usage_records_test'
require 'shaka/github/squash_comment'
require 'shaka/usage/records'

# https://github.com/shakacode/shaka/issues/605: a description quoting one of Shaka's own
# markers published once, then left every reader of the managed region failing.
class PublicationQuotedMarkersTest < Minitest::Test
  include GitHubHelper
  include UsageRecordsFixture

  MARKERS = [
    Shaka::Publishing::OPEN_MARK, Shaka::Publishing::CLOSE_MARK,
    Shaka::MergeWarningRegion::OPEN, Shaka::MergeWarningRegion::CLOSE,
    Shaka::ProvenanceHistory::PREFIX.strip, Shaka::HumanComments::OPEN_MARK, Shaka::HumanComments::CLOSE_MARK,
    Shaka::PublicationSections::MARKER, Shaka::StepsBesidesMerging::MARKER,
    Shaka::UsageRecords::BEGIN_PREFIX.strip, Shaka::UsageRecords::END_MARK,
    Shaka::SquashComment::SQUASH_MARK, '<!-- shaka:reply:fix-1 -->'
  ].freeze

  def content(**changes) = PublicationRegressionTest.new('content').description_content(**changes)

  def test_a_summary_quoting_any_shaka_marker_is_refused_naming_it
    MARKERS.each do |marker|
      error = assert_raises(Shaka::Error, marker) do
        Shaka::Publication.description(content('summary' => "Moves the `#{marker}` check."))
      end
      assert_includes error.message, marker[%r{\A<!-- /?shaka:[\w:.-]*}], marker
      assert_includes error.message, 'summary'
    end
  end

  def test_a_marker_in_nested_content_names_where_it_was_found
    sections = [{ 'heading' => 'Outcome', 'body' => 'Quotes <!-- shaka:begin --> here.' }]
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(content('sections' => sections)) }
    assert_includes error.message, 'sections[0].body'
  end

  def test_a_refused_description_writes_nothing_to_the_pull_request
    github = client(response({ 'id' => 1, 'number' => 42, 'body' => '' }))
    quoted = content('summary' => 'Moves the `<!-- shaka:end -->` marker check.')
    assert_raises(Shaka::Error) { github.description { Shaka::Publication.description(quoted) } }
    assert_equal 1, @calls.size, 'only the pull request read may happen'
  end

  # Break: checking the carried reports refused every republish that kept earlier usage.
  def test_usage_carried_from_the_earlier_body_still_renders
    earlier = existing(record('codex', 'codex-review', responses: %w[r1], sources: ['s9'], contribution: 'review'))
    carried, = Shaka::UsageRecords.carry(content, earlier)
    assert_includes carried.dig('usage', 'carried'), Shaka::UsageRecords::END_MARK
    assert_includes Shaka::Publication.description(carried), 'codex-review'
  end

  # Issue #1344: the paragraph after the marked line reads back as setup gaps when it is the helper's sentence.
  GAPS_LINE = '**Setup gaps:** 1 of 2 configured reviewers completed.'
  AGENT_FIELDS = {
    'verification.summary' => ->(text) { { 'verification' => VERIFICATION.merge('summary' => "#{text} `x`") } },
    'sections[0].body' => ->(text) { { 'sections' => [{ 'heading' => 'Outcome', 'body' => "First.\n\n#{text}" }] } },
    'risk_record.body' => ->(text) { { 'risk_record' => { 'summary' => 'Low.', 'body' => text } } }
  }.freeze

  def test_agent_text_starting_a_line_with_the_setup_gaps_label_is_refused_naming_the_field
    AGENT_FIELDS.each do |field, change|
      error = assert_raises(Shaka::Error, field) { Shaka::Publication.description(content(**change.call(GAPS_LINE))) }
      assert_includes error.message, field
    end
  end

  # The marker, not these lines, finds the helper's own result, so free-form text may show them.
  def test_other_verification_lines_and_an_inline_label_still_render
    summary = "Refuses a line starting with `**Setup gaps:**`.\n\n## Verification\n\n" \
              '**Validation and review:** passed, as an example.'
    assert_includes Shaka::Publication.description(content('summary' => summary)), summary
  end

  def test_marker_names_without_comment_delimiters_still_render
    assert_includes Shaka::Publication.description(content('summary' => 'Moves the `shaka:end` check.')),
                    '`shaka:end`'
  end
end
