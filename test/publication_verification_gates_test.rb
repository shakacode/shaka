# frozen_string_literal: true

require_relative 'publication_test'

# The description already receives the validation and review results, so Ruby writes their
# line; the agent's checks are left for proof specific to the change.
class PublicationVerificationGatesTest < Minitest::Test
  HEAD = "abcdef1#{'0' * 33}".freeze
  VALIDATE = { 'kind' => 'validation', 'command' => 'validate', 'status' => 'completed', 'exit_code' => 0 }.freeze
  CLAUDE = { 'kind' => 'review', 'reviewer' => 'anthropic/claude', 'status' => 'completed', 'head' => HEAD }.freeze
  CODEX = { 'kind' => 'review', 'reviewer' => 'openai/codex', 'status' => 'reported', 'head' => HEAD }.freeze
  SHORTFALL = { 'configured' => 2, 'completed' => 1, 'missing' => ['openai'] }.freeze
  URL = 'https://github.com/shakacode/shaka/pull/9#issuecomment-1'

  def render(settings, **changes)
    Shaka::Publication.description(PublicationRegressionTest.new(name).description_content(**changes),
                                   nil, nil, settings)
  end

  def bound(validation: [VALIDATE], review: [CLAUDE], shortfall: nil)
    checks = { 'validation' => validation, 'review' => review }.transform_values do |results|
      results.map { |result| { 'status' => 'bound', 'original' => result } }
    end
    Shaka::PublicationSettings.new(verdict: { 'status' => 'ready', 'head' => HEAD, 'checks' => checks },
                                   reviewer_shortfall: shortfall)
  end

  # Eleven of twelve PRs after #553 spent two of three checks restating validate and local review.
  def test_bound_results_render_one_validation_and_review_line_before_the_checks
    rendered = render(bound(review: [CLAUDE, CODEX]), 'review' => URL)

    line = '**Validation and review:** `validate` passed (exit 0); local review by anthropic/claude, ' \
           "openai/codex (host-reported) ([attestation](#{URL})) at `abcdef1`."
    assert_includes rendered, line
  end

  # https://github.com/shakacode/shaka/issues/777: a reader looks for what failed, so a routine run folds.
  # A completed review can still report findings, so the summary does not call it a pass.
  def test_a_passing_validation_and_completed_review_have_a_compact_visible_summary
    rendered = render(bound)
    assert_includes rendered, "## Verification\n\nValidation passed; local review completed at abcdef1."
    refute_includes rendered, '**Setup gaps:**'
    assert_operator rendered.index('<summary>Evidence and limitations</summary>'), :<,
                    rendered.index('**Validation and review:**')
  end

  # A host-reported review is only attested, so its reviewer stays in view.
  def test_a_failure_a_missing_review_or_a_host_reported_review_stays_visible
    [bound(validation: [VALIDATE.merge('exit_code' => 1)]), bound(review: []),
     bound(review: [CLAUDE, CODEX])].each do |settings|
      assert_includes render(settings), "## Verification\n\n**Validation and review:**"
    end
  end

  # Binding accepts any completed run, so a failed validate must not read as a pass.
  def test_a_failed_validation_is_reported_with_its_exit_code
    rendered = render(bound(validation: [VALIDATE.merge('exit_code' => 1)]))

    assert_includes rendered, '`validate` failed (exit 1); local review by anthropic/claude at `abcdef1`.'
  end

  # The first description is published before the review comment exists, so it has no link yet.
  def test_the_line_names_reviewers_without_a_link_before_review_publication
    refute_includes render(bound), '[attestation]'
  end

  def test_without_results_the_line_says_none_were_supplied
    rendered = render(nil)
    assert_includes rendered, "## Verification\n\n#{Shaka::VerificationGates::UNKNOWN}\n\n"
    refute_includes rendered, '**Setup gaps:**'
  end

  # https://github.com/shakacode/shaka/issues/887: a completed review folded even when fewer
  # reviewers ran than the repository configured. The folded evidence keeps only the line.
  def test_a_reviewer_shortfall_keeps_the_line_visible_and_names_the_missing_provider
    rendered = render(bound(shortfall: SHORTFALL), 'review' => URL)

    line = '**Validation and review:** `validate` passed (exit 0); local review by anthropic/claude ' \
           "([attestation](#{URL})) at `abcdef1`."
    gaps = "**Setup gaps:** 1 of 2 configured reviewers completed; `openai` did not ([review comment](#{URL}))."
    assert_includes rendered, "## Verification\n\n#{line}\n\n#{gaps}\n\n"
    assert_equal 1, rendered.scan('**Setup gaps:**').size
  end

  # local_review_count says how many, not which, and the review comment comes after the first description.
  def test_a_count_shortfall_names_no_provider_and_links_nothing_before_review_publication
    rendered = render(bound(shortfall: SHORTFALL.merge('missing' => [])))

    assert_includes rendered, "at `abcdef1`.\n\n**Setup gaps:** 1 of 2 configured reviewers completed.\n\n"
  end
end
