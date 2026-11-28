# frozen_string_literal: true

require_relative 'cli_description_decisions_test'
require 'shaka/publication/verification_line'

# PR #998: a wording-only rewrite after an install update had nowhere to go but UNKNOWN.
class CliDescriptionKeptResultsTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes
  include CliDescriptionDecisionsRun

  COMMAND = SHAKA_COMMAND
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Rewording keeps verified results.'
  LINE = '**Validation and review:** `validate` passed (exit 0); local review by openai/codex at `ccccccc`.'
  # A description published before passes dropped their exit code shows the trimmed line on republish.
  SHOWN = LINE.sub(' (exit 0)', '')
  KEPT = 'not rechecked under the current Shaka or settings'

  def test_rewording_keeps_the_verified_line_and_reports_that_it_was_not_rechecked
    fold = "<details>\n<summary>Evidence and limitations</summary>\n\n#{LINE}\n\n</details>"
    published, result = republish("<!-- shaka:begin -->\n## Verification\n\n#{LINE}\n\n#{fold}\n<!-- shaka:end -->")

    assert_includes published, "#{SHOWN} Kept from this commit’s earlier description"
    refute_includes published, '(exit 0)'
    refute_includes published, 'UNKNOWN: no validation or review results'
    assert_includes result.fetch('evidence_kept'), KEPT
  end

  # The helper marks the line it writes, and the command reads that line back.
  def test_rewording_keeps_the_marked_line
    marker = Shaka::VerificationLine::MARKER
    marked = "## Verification\n\n#{marker}\n#{SHOWN}"
    published, result = republish("<!-- shaka:begin -->\n#{marked}\n<!-- shaka:end -->")

    assert_includes published, "#{marker}\n#{SHOWN} Kept from this commit’s earlier description"
    assert_includes result.fetch('evidence_kept'), KEPT
  end

  # https://github.com/shakacode/shaka/issues/1320: a summary worded like the line was kept as verified.
  def test_a_summary_worded_like_the_line_is_not_kept
    unknown = '**Validation and review:** UNKNOWN: no validation or review results were supplied for this revision.'
    published, result = republish("<!-- shaka:begin -->\n## Verification\n\n#{unknown}\n\n#{SHOWN}\n<!-- shaka:end -->")

    assert_includes published, unknown
    assert_nil result['evidence_kept']
  end

  def test_a_description_without_a_verified_line_still_shows_unknown
    published, result = republish('<!-- shaka:begin -->nothing verified<!-- shaka:end -->')

    assert_includes published, 'UNKNOWN: no validation or review results'
    refute_includes published, KEPT
    refute result.key?('evidence_kept')
  end

  # Issue #1320: the agent's own summary, worded like the line, came back as a kept pass.
  def test_a_summary_worded_like_the_line_stays_unknown_across_republishes
    @summary = SHOWN
    first, = republish('')
    second, result = republish(first)

    assert_includes second, 'UNKNOWN: no validation or review results'
    refute_includes second, KEPT
    refute result.key?('evidence_kept')
  end

  # PR #1301: without results, the line also names a published review that covers the head.
  def test_without_results_a_published_review_of_the_head_is_named
    url = 'https://github.com/owner/repo/pull/1#issuecomment-5'
    comment = { 'user' => { 'login' => 'agent' }, 'html_url' => url,
                'body' => "Review.\n\nREVIEWED #{'c' * 40} BY openai/codex EFFORT high FINDINGS 0\n" }
    published, = republish('', env: { 'PR_COMMENTS' => JSON.generate([comment]) })

    line = "were supplied for this revision. A [local review](#{url}) of this revision is published"
    assert_includes published, line
  end

  # Issue #1187: a later publication cannot quietly replace the plan-time recommendation.
  def test_a_changed_recommendation_keeps_the_recorded_one_and_says_so
    entry = { 'head' => 'b' * 40, 'workflow' => '`1.0.0` (commit unknown)', 'requested' => 'Not specified',
              'recommended' => 'claude-opus-5-5 / high', 'active' => 'gpt-5.6-terra / medium' }
    marker = "<!-- shaka:provenance #{JSON.generate('entries' => [entry], 'omitted' => 0)} -->"
    published, result = republish("<!-- shaka:begin -->\n#{marker}\n<!-- shaka:end -->")

    assert_includes published, '| Recommended model / effort | claude-opus-5-5 / high |'
    assert_includes result.fetch('recommendation_kept'), 'claude-opus-5-5 / high'
  end

  private

  def republish(existing, env: {})
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        env = { 'EXISTING_BODY' => existing }.merge(env)
        output, error, status = run_description(dir, root:, env:, decisions: false)
        assert_predicate status, :success?, error
        return [File.read(File.join(dir, 'published.md')), JSON.parse(output)]
      end
    end
  end

  def description_content
    content = super
    content['verification'] = content['verification'].merge('summary' => @summary) if @summary
    content
  end

  def fake_gh = DESCRIPTION_GH
end
