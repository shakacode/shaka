# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/published_results'

# The description already receives the validation and review results, so Ruby writes their
# line; the agent's checks are left for proof specific to the change.
class PublicationVerificationLineTest < Minitest::Test
  VERIFIED = "## Verification\n\n#{Shaka::VerificationLine::MARKER}\n".freeze
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

    line = '**Validation and review:** `validate` passed; local review by anthropic/claude, ' \
           "openai/codex (host-reported) ([attestation](#{URL})) at `abcdef1`."
    assert_includes rendered, line
  end

  # https://github.com/shakacode/shaka/issues/1325: a routine run showed a summary and then the line in the fold.
  def test_a_passing_validation_and_completed_review_show_the_line_once
    rendered = render(bound, 'review' => URL)
    line = "**Validation and review:** `validate` passed; local review by anthropic/claude ([attestation](#{URL})) " \
           'at `abcdef1`.'
    assert_includes rendered, "#{VERIFIED}#{line}\n\n<details>"
    assert_equal 1, rendered.scan('**Validation and review:**').size
    refute_includes rendered, '**Setup gaps:**'
  end

  # A wording-only republish keeps the line it reads back from the body the helper rendered.
  def test_a_rendered_line_and_its_gaps_read_back_and_render_unchanged
    [bound, bound(shortfall: SHORTFALL)].each do |settings|
      kept = read_back(render(settings, 'review' => URL))
      verification = Shaka::VerificationLine.render(settings.verdict, URL, settings.reviewer_shortfall)
      assert_equal verification.sub('`abcdef1`.', "`abcdef1`. #{Shaka::VerificationLine::KEPT}"),
                   Shaka::VerificationLine.render(kept, URL)
      assert_equal kept, read_back(render(Shaka::PublicationSettings.new(verdict: kept), 'review' => URL))
    end
  end

  # Free-form text may show the headings: a fenced example in the summary or a section of its own.
  def test_a_line_reads_back_beside_a_fenced_example_or_a_section_with_the_same_heading
    example = "Example:\n\n```markdown\nAn example description.\n\n## Verification\n\nIt passed.\n```"
    shapes = [{ 'summary' => example }, { 'sections' => [{ 'heading' => 'Verification', 'body' => 'More notes.' }] }]
    assert_empty(shapes.reject { |extra| read_back(render(bound, 'review' => URL, **extra)) })
  end

  # A host-reported review is only attested, so its reviewer stays in view.
  def test_a_failure_a_missing_review_or_a_host_reported_review_stays_visible
    [bound(validation: [VALIDATE.merge('exit_code' => 1)]), bound(review: []),
     bound(review: [CLAUDE, CODEX])].each do |settings|
      assert_includes render(settings), "#{VERIFIED}**Validation and review:**"
    end
  end

  # Binding accepts any completed run, so a failed validate must not read as a pass.
  def test_a_failed_validation_is_reported_with_its_exit_code
    rendered = render(bound(validation: [VALIDATE.merge('exit_code' => 1)]))

    assert_includes rendered, '`validate` failed (exit 1); local review by anthropic/claude at `abcdef1`.'
    assert_includes render(bound(validation: [VALIDATE.merge('exit_code' => nil)])), '`validate` failed; local review'
  end

  # The first description is published before the review comment exists, so it has no link yet.
  def test_the_line_names_reviewers_without_a_link_before_review_publication
    refute_includes render(bound), '[attestation]'
  end

  def test_without_results_the_line_says_none_were_supplied
    rendered = render(nil)
    assert_includes rendered, "#{VERIFIED}#{Shaka::VerificationLine::UNKNOWN}\n\n"
    refute_includes rendered, '**Setup gaps:**'
  end

  # https://github.com/shakacode/shaka/issues/887: a completed review folded even when fewer
  # reviewers ran than the repository configured.
  def test_a_reviewer_shortfall_keeps_the_line_visible_and_names_the_missing_provider
    rendered = render(bound(shortfall: SHORTFALL), 'review' => URL)

    line = '**Validation and review:** `validate` passed; local review by anthropic/claude ' \
           "([attestation](#{URL})) at `abcdef1`."
    gaps = "**Setup gaps:** 1 of 2 configured reviewers completed; `openai` did not ([review comment](#{URL}))."
    assert_includes rendered, "#{VERIFIED}#{line}\n\n#{gaps}\n\n"
    assert_equal 1, rendered.scan('**Setup gaps:**').size
  end

  # local_review_count says how many, not which, and the review comment comes after the first description.
  def test_a_count_shortfall_names_no_provider_and_links_nothing_before_review_publication
    rendered = render(bound(shortfall: SHORTFALL.merge('missing' => [])))

    assert_includes rendered, "at `abcdef1`.\n\n**Setup gaps:** 1 of 2 configured reviewers completed.\n\n"
  end

  # PR #1301: a review of the commit before main was merged in still covered the head, yet the line
  # read as if nothing had been checked.
  def test_without_results_a_sentence_about_a_review_that_still_covers_the_head_follows
    covered = 'The local review of `e33df55` covers this revision, which only updates it from `main`.'
    rendered = render(Shaka::PublicationSettings.new.with_earlier_review(covered))

    assert_includes rendered, "#{VERIFIED}#{Shaka::VerificationLine::UNKNOWN} #{covered}\n\n"
    assert_equal 1, rendered.scan(Shaka::VerificationLine::UNKNOWN).size
  end

  private

  def read_back(body)
    pull = { 'body' => "<!-- shaka:begin -->\n#{body}<!-- shaka:end -->",
             'head' => { 'sha' => HEAD, 'repo' => { 'full_name' => 'shakacode/shaka' } } }
    Shaka::PublishedResults.read(pull, 'shakacode/shaka')
  end
end
