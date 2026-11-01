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
  KEPT = 'not rechecked under the current Shaka or settings'

  def test_rewording_keeps_the_verified_line_and_reports_that_it_was_not_rechecked
    published, result = republish("<!-- shaka:begin -->\n#{LINE}\n<!-- shaka:end -->")

    assert_includes published, "#{LINE} Kept from this commit’s earlier description"
    assert_includes published, "\n#{LINE}\n"
    refute_includes published, 'UNKNOWN: no validation or review results'
    assert_includes result.fetch('evidence_kept'), KEPT
  end

  def test_a_description_without_a_verified_line_still_shows_unknown
    published, result = republish('<!-- shaka:begin -->nothing verified<!-- shaka:end -->')

    assert_includes published, 'UNKNOWN: no validation or review results'
    refute_includes published, KEPT
    refute result.key?('evidence_kept')
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
