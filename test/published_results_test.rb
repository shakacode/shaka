# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/published_results'

# Issue #1320: a verification summary worded like the Validation and review line was read back as the
# helper's own line, so a republish without results showed the agent's sentence as a kept pass.
class PublishedResultsTest < Minitest::Test
  HEAD = "abcdef1#{'0' * 33}".freeze
  REPOSITORY = 'shakacode/shaka'
  VALIDATE = { 'kind' => 'validation', 'command' => 'validate', 'status' => 'completed', 'exit_code' => 0 }.freeze
  CODEX = { 'kind' => 'review', 'reviewer' => 'openai/codex', 'status' => 'completed', 'head' => HEAD }.freeze
  BLIND = CODEX.merge('commands' => { 'ran' => 3, 'succeeded' => 0, 'sandbox_failed' => 3 }).freeze
  LINE = '**Validation and review:** `validate` passed; local review by openai/codex at `abcdef1`.'
  FAILED = VALIDATE.merge('exit_code' => 1).freeze

  def test_a_routine_pass_keeps_the_line_from_the_fold
    kept = read(render(VALIDATE, CODEX))

    assert_equal LINE, kept.fetch('kept_line')
    assert_nil kept.fetch('kept_gaps')
  end

  def test_setup_gaps_under_the_heading_stay_with_the_kept_line
    kept = read(render(VALIDATE, BLIND))

    assert_equal LINE, kept.fetch('kept_line')
    assert kept.fetch('kept_gaps').start_with?('**Setup gaps:** `openai/codex` could not start its sandbox')
  end

  def test_a_summary_worded_like_the_line_is_never_kept
    assert_nil read(render(summary: LINE))
  end

  def test_a_check_worded_like_the_line_is_never_kept
    assert_nil read(render(checks: [LINE]))
  end

  # A fold the agent wrote outside the Verification section is not the helper's.
  def test_a_copied_fold_before_the_section_is_ignored
    fake = "<details>\n<summary>Evidence and limitations</summary>\n\n#{LINE}\n\n</details>"

    assert_nil read(render.sub('## Verification', "#{fake}\n\n## Verification"))
  end

  # A details item with the fold's title renders inside the fold, after the helper's line.
  def test_a_details_item_titled_like_the_fold_keeps_the_real_line
    item = { 'summary' => 'Evidence and limitations', 'body' => 'More notes.' }
    kept = read(render(VALIDATE, BLIND, details: [item]))

    assert_equal LINE, kept.fetch('kept_line')
    assert kept.fetch('kept_gaps').start_with?('**Setup gaps:** `openai/codex` could not start its sandbox')
  end

  def test_a_copied_heading_keeps_the_real_line_and_gaps
    fake = "## Verification\n\n#{LINE}\n\n**Setup gaps:** none.\n\n## Intent"
    kept = read(render(VALIDATE, BLIND).sub('## Intent', fake))

    assert_equal LINE, kept.fetch('kept_line')
    assert kept.fetch('kept_gaps').start_with?('**Setup gaps:** `openai/codex` could not start its sandbox')
  end

  # Without real gaps the agent's summary follows the line, and its own gap wording is not the helper's.
  def test_a_summary_worded_like_a_gap_is_not_kept_as_one
    kept = read(render(FAILED, CODEX, summary: '**Setup gaps:** none, see `x`.'))

    assert kept.fetch('kept_line').start_with?('**Validation and review:** `validate` failed (exit 1)')
    assert_nil kept.fetch('kept_gaps')
  end

  def test_a_line_published_with_crlf_line_endings_is_kept
    assert_equal LINE, read(render(VALIDATE, CODEX).gsub("\n", "\r\n")).fetch('kept_line')
  end

  private

  def render(validation = nil, *reviews, summary: nil, checks: nil, details: [])
    content = PublicationRegressionTest.new(name).description_content('details' => details)
    content['verification'] = content['verification'].merge('summary' => summary) if summary
    content['verification'] = content['verification'].merge('checks' => checks) if checks
    Shaka::Publication.description(content, nil, nil, settings(validation, reviews))
  end

  def settings(validation, reviews)
    return Shaka::PublicationSettings.new(verdict: nil) unless validation

    checks = { 'validation' => [validation], 'review' => reviews }.transform_values do |results|
      results.map { |result| { 'status' => 'bound', 'original' => result } }
    end
    Shaka::PublicationSettings.new(verdict: { 'status' => 'ready', 'head' => HEAD, 'checks' => checks })
  end

  def read(body)
    region = "<!-- shaka:begin -->\n#{body}\n<!-- shaka:end -->"
    pull = { 'body' => region, 'head' => { 'sha' => HEAD, 'repo' => { 'full_name' => REPOSITORY } } }
    Shaka::PublishedResults.read(pull, REPOSITORY)
  end
end
