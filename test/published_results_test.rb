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

  # Agent Markdown that copies the fold leaves two candidates, and the helper cannot tell which it wrote.
  def test_a_copied_fold_keeps_nothing
    fake = "<details>\n<summary>Evidence and limitations</summary>\n\n#{LINE}\n\n</details>"
    body = render(VALIDATE, CODEX).sub('## Verification', "#{fake}\n\n## Verification")

    assert_nil read(body)
  end

  def test_a_copied_heading_drops_only_the_gaps
    body = render(VALIDATE, BLIND).sub('## Intent', "## Verification\n\n#{LINE}\n\n**Setup gaps:** none.\n\n## Intent")

    kept = read(body)
    assert_equal LINE, kept.fetch('kept_line')
    assert_nil kept.fetch('kept_gaps')
  end

  def test_a_line_published_with_crlf_line_endings_is_kept
    assert_equal LINE, read(render(VALIDATE, CODEX).gsub("\n", "\r\n")).fetch('kept_line')
  end

  private

  def render(validation = nil, *reviews, summary: nil, checks: nil)
    content = PublicationRegressionTest.new(name).description_content
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
