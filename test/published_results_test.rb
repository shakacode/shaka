# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/published_results'

# Issue #1320: a verification summary worded like the Validation and review line was read back as the
# helper's own line, so a republish without results showed the agent's sentence as a kept pass.
class PublishedResultsTest < Minitest::Test
  HEAD = "abcdef1#{'0' * 33}".freeze
  REPOSITORY = 'shakacode/shaka'
  VALIDATE = { 'kind' => 'validation', 'command' => 'validate', 'status' => 'completed', 'exit_code' => 0 }.freeze
  FAILED = VALIDATE.merge('exit_code' => 1).freeze
  CODEX = { 'kind' => 'review', 'reviewer' => 'openai/codex', 'status' => 'completed', 'head' => HEAD }.freeze
  BLIND = CODEX.merge('commands' => { 'ran' => 3, 'succeeded' => 0, 'sandbox_failed' => 3 }).freeze
  LINE = '**Validation and review:** `validate` passed; local review by openai/codex at `abcdef1`.'
  REVIEW_URL = 'https://github.com/shakacode/shaka/pull/1#issuecomment-2'
  GAP = '**Setup gaps:** `openai/codex` could not start its sandbox, so it reviewed only the diff'
  # A list carried from the published body renders between the Verification section and the fold.
  COMMENTS = "<!-- shaka:human-comments -->\n## Human comments\n\n1 comment · read at `abcdef1`\n\n" \
             "| From | Said | Response | Status |\n| --- | --- | --- | --- |\n| @someone | Looks good. | — | open |" \
             "\n\n<!-- /shaka:human-comments -->"

  def test_a_routine_pass_keeps_the_line_from_the_fold
    kept = read(render(VALIDATE, CODEX))

    assert_equal LINE, kept.fetch('kept_line')
    assert_nil kept.fetch('kept_gaps')
  end

  def test_setup_gaps_under_the_heading_stay_with_the_kept_line
    kept = read(render(VALIDATE, BLIND))

    assert_equal LINE, kept.fetch('kept_line')
    assert kept.fetch('kept_gaps').start_with?(GAP)
  end

  def test_a_human_comments_list_before_the_fold_keeps_the_line_and_gaps
    [render(VALIDATE, CODEX, comments: true), render(VALIDATE, BLIND, comments: true)].each do |body|
      assert_includes body, '## Human comments'
      assert_equal LINE, read(body).fetch('kept_line')
    end
    assert read(render(VALIDATE, BLIND, comments: true)).fetch('kept_gaps').start_with?(GAP)
  end

  def test_a_summary_worded_like_the_line_is_never_kept
    assert_nil read(render(summary: LINE))
  end

  def test_a_check_worded_like_the_line_is_never_kept
    assert_nil read(render(checks: [LINE]))
  end

  # A details item renders inside the fold after the helper's own line, so the real fold decides.
  def test_a_details_item_titled_like_the_fold_cannot_supply_the_line
    item = { 'summary' => 'Evidence and limitations', 'body' => LINE }

    assert_nil read(render(details: [item]))
    kept = read(render(VALIDATE, BLIND, details: [item]))
    assert_equal LINE, kept.fetch('kept_line')
    assert kept.fetch('kept_gaps').start_with?(GAP)
  end

  def test_a_copied_heading_keeps_the_real_line_and_gaps
    fake = "## Verification\n\n#{LINE}\n\n**Setup gaps:** none.\n\n## Intent"
    kept = read(render(VALIDATE, BLIND).sub('## Intent', fake))

    assert_equal LINE, kept.fetch('kept_line')
    assert kept.fetch('kept_gaps').start_with?(GAP)
  end

  # Without real gaps the agent's summary follows the line; only the helper's whole gap sentence counts.
  def test_a_summary_worded_like_a_gap_is_not_kept_as_one
    summary = '**Setup gaps:** 1 of 2 configured reviewers completed, see `x`.'
    kept = read(render(FAILED, CODEX, summary:))

    assert kept.fetch('kept_line').start_with?('**Validation and review:** `validate` failed (exit 1)')
    assert_nil kept.fetch('kept_gaps')
  end

  # The reader copies the helper's gap sentences, so every form the helper writes must read back whole.
  def test_every_setup_gap_the_helper_writes_is_kept_verbatim
    shortfalls = [{ 'completed' => 1, 'configured' => 2, 'missing' => [] },
                  { 'completed' => 1, 'configured' => 3, 'missing' => %w[anthropic xai] }]
    [*shortfalls.product([nil, REVIEW_URL], [CODEX, BLIND]), [nil, nil, BLIND], [nil, REVIEW_URL, BLIND]]
      .each do |shortfall, url, review|
        body = render(VALIDATE, review, review: url, shortfall:)
        shown = body[/^\*\*Setup gaps:\*\* .+$/]
        assert_equal shown, read(body).fetch('kept_gaps'), body
      end
  end

  def test_a_line_published_with_crlf_line_endings_is_kept
    kept = read(render(VALIDATE, BLIND).gsub("\n", "\r\n"))

    assert_equal LINE, kept.fetch('kept_line')
    assert kept.fetch('kept_gaps').start_with?(GAP)
  end

  private

  def render(validation = nil, *reviews, summary: nil, checks: nil, details: [], comments: false, **links) # rubocop:disable Metrics/ParameterLists
    content = PublicationRegressionTest.new(name).description_content('details' => details, 'review' => links[:review])
    content['verification'] = content['verification'].merge('summary' => summary) if summary
    content['verification'] = content['verification'].merge('checks' => checks) if checks
    settings = settings(validation, reviews, links[:shortfall])
    Shaka::Publication.description(content, nil, (pull(region(COMMENTS)) if comments), settings)
  end

  def settings(validation, reviews, shortfall)
    return Shaka::PublicationSettings.new(verdict: nil) unless validation

    checks = { 'validation' => [validation], 'review' => reviews }.transform_values do |results|
      results.map { |result| { 'status' => 'bound', 'original' => result } }
    end
    verdict = { 'status' => 'ready', 'head' => HEAD, 'checks' => checks }
    Shaka::PublicationSettings.new(verdict:, reviewer_shortfall: shortfall)
  end

  def region(text) = "<!-- shaka:begin -->\n#{text}\n<!-- shaka:end -->"

  def pull(body)
    repo = { 'full_name' => REPOSITORY }
    { 'number' => 1, 'body' => body, 'head' => { 'sha' => HEAD, 'repo' => repo }, 'base' => { 'repo' => repo } }
  end

  def read(body) = Shaka::PublishedResults.read(pull(region(body)), REPOSITORY)
end
