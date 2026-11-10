# frozen_string_literal: true

require_relative 'post_implementation_publication_test'

# A maintainer reads the warning without knowing how Shaka works, so it leads with the situation, quotes the
# owner's own reason and next step, and leaves workflow terms out of the visible text.
class PostImplementationMergeWarningWordingTest < Minitest::Test
  include PostImplementationPublicationFixture

  REGION = Shaka::MergeWarningRegion
  QUESTION = 'Can we use the two completed reviews? Both found no blocking issues, but the CI review job ' \
             'did not publish its report. I recommend accepting them; the alternative is to wait for a fix.'
  INTERNAL_TERMS = ['checkpoint', 'task owner', 'gates', 'disposition', 'post-implementation'].freeze

  def concern(result, text)
    report = JSON.parse(File.read(result['report'])).merge('conclusion' => 'Simplify/reframe', 'concerns' => [text])
    File.write(result['report'], JSON.generate(report))
  end

  def dispose(result, recommendation, reason, next_action)
    result['disposition'] = { 'head' => result['head'], 'recommendation' => recommendation,
                              'reason' => reason, 'next_action' => next_action }
  end

  # The visible warning: the marked region without its HTML comments.
  def warning(github)
    body = github.description_body
    body[body.index(REGION::OPEN)...body.index(REGION::CLOSE)].gsub(/<!--.*?-->\n?/, '')
  end

  def assert_plain(text)
    INTERNAL_TERMS.each { |term| refute_match(/#{term}/i, text) }
  end

  def test_a_missing_review_report_asks_the_maintainer_and_says_an_answer_is_not_merge_approval
    with_result do |result, path|
      concern(result, 'The CI review job finished without publishing its report.')
      dispose(result, Shaka::PostImplementationReport::AWAITING_DECISION, QUESTION, 'Ask Justin.')
      text = warning(publish(result, path).first)

      [REGION::AWAITING.first, QUESTION, 'Your answer does not approve merging.'].each { assert_includes text, it }
      refute_includes text, 'Ask Justin.'
      assert_plain(text)
    end
  end

  def test_an_unresolved_defect_shows_the_problem_and_the_agents_next_step
    with_result do |result, path|
      concern(result, 'A timeout can send the same email twice.')
      dispose(result, 'Revise before merge', 'A mail server timeout can make the retry send the same email twice.',
              "Add a duplicate-send check with a test,\nthen run the review again.")
      text = warning(publish(result, path).first)

      assert_includes text, REGION::BLOCKED.first
      assert_includes text, '**Next:** Add a duplicate-send check with a test, then run the review again.'
      refute_includes text, REGION::BLOCKED.last
      assert_plain(text)
    end
  end

  def test_a_dependency_on_another_pr_names_that_pr_as_the_next_step
    with_result do |result, path|
      concern(result, 'This PR depends on #570.')
      dispose(result, 'Revise before merge', 'This PR reads the time zone setting that #570 adds.',
              'Wait for #570 to merge, then rebase this PR.')
      text = warning(publish(result, path).first)

      assert_includes text, 'This PR reads the time zone setting that #570 adds.'
      assert_includes text, '**Next:** Wait for #570 to merge, then rebase this PR.'
      assert_plain(text)
    end
  end

  def test_a_reviewer_recommending_against_the_pr_asks_the_maintainer_to_close_or_replace_it
    with_result do |result, path|
      report = JSON.parse(File.read(result['report'])).merge('conclusion' => 'Do not merge')
      File.write(result['report'], JSON.generate(report))
      text = warning(publish(result, path).first)

      assert_includes text, REGION::REJECTED.first
      refute_includes text, 'You do not need to answer anything yet.'
      assert_plain(text)
    end
  end

  def test_a_review_that_did_not_finish_is_not_reported_as_a_problem_in_the_code
    with_result do |result, path|
      text = warning(publish(result.merge('status' => 'not_completed', 'reason' => 'The reviewer timed out.'),
                             path).first)

      assert_includes text, REGION::INCOMPLETE.first
      assert_includes text, 'The reviewer timed out.'
      refute_includes text, REGION::BLOCKED.first
      assert_plain(text)
    end
  end
end
