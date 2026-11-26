# frozen_string_literal: true

require_relative 'cli_description_decisions_test'

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
    published, result = republish("<!-- shaka:begin -->\n#{LINE}\n<!-- shaka:end -->")

    assert_includes published, "#{SHOWN} Kept from this commit’s earlier description"
    refute_includes published, '(exit 0)'
    refute_includes published, 'UNKNOWN: no validation or review results'
    assert_includes result.fetch('evidence_kept'), KEPT
  end

  def test_a_description_without_a_verified_line_still_shows_unknown
    published, result = republish('<!-- shaka:begin -->nothing verified<!-- shaka:end -->')

    assert_includes published, 'UNKNOWN: no validation or review results'
    refute_includes published, KEPT
    refute result.key?('evidence_kept')
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

  def republish(existing)
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, env: { 'EXISTING_BODY' => existing }, decisions: false)
        assert_predicate status, :success?, error
        return [File.read(File.join(dir, 'published.md')), JSON.parse(output)]
      end
    end
  end

  def fake_gh = DESCRIPTION_GH
end
