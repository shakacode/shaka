# frozen_string_literal: true

require_relative 'publication_human_comments_test'

# https://github.com/shakacode/shaka/issues/887: an agent that replied with `gh` instead of
# `shaka reply` left no identity line, and the description listed its replies as the PR author's.
class PublicationUnlabeledCommentsTest < Minitest::Test
  include HumanCommentsFixture

  GAPS = '**Setup gaps:**'
  SHORTFALL = { 'configured' => 2, 'completed' => 1, 'missing' => ['openai'] }.freeze

  def test_the_author_s_unlabeled_comments_are_counted_under_verification
    comments = packet(inline_comments: [inline(1, 'bot[bot]', 'Rename this.'), inline(2, 'ann', 'Renamed it.')],
                      issue_comments: [issue_comment(3, 'Ann', 'Applied in abc1234.')])

    assert_includes describe(comments), "#{GAPS} 2 comments from the PR author have no AI identity line; " \
                                        "if an agent wrote them, add the line.\n\n"
  end

  def test_one_unlabeled_comment_is_named_in_the_singular
    rendered = describe(packet(issue_comments: [issue_comment(3, 'ann', 'Applied in abc1234.')]))

    assert_includes rendered, "#{GAPS} 1 comment from the PR author has no AI identity line; " \
                              'if an agent wrote it, add the line.'
  end

  # Agent posts, bots, and other people's comments are not the author's unlabeled words.
  def test_marked_posts_and_other_authors_leave_no_gap
    comments = packet(issue_comments: [issue_comment(3, 'ann', REPLY), issue_comment(4, 'bob', 'Looks good.'),
                                       issue_comment(5, 'helper[bot]', 'Deployed.')],
                      inline_comments: [inline(6, 'ann', "#{IDENTITY}\n\nFixed.")])

    refute_includes describe(comments), GAPS
  end

  def test_the_count_stays_when_the_repository_hides_the_comment_list
    rendered = describe(packet(issue_comments: [issue_comment(3, 'ann', 'Applied.')]),
                        settings: { 'pr_description.show_human_comments' => false })

    refute_includes rendered, Shaka::HumanComments::OPEN_MARK
    assert_includes rendered, "#{GAPS} 1 comment from the PR author"
  end

  # The count is not about the checks, so a routine run keeps its folded summary above the gap.
  def test_a_routine_run_stays_folded_above_the_unlabeled_count
    check = ->(result) { [{ 'status' => 'bound', 'original' => result }] }
    verdict = { 'status' => 'ready', 'head' => HEAD, 'checks' => {
      'validation' => check.call({ 'command' => 'validate', 'status' => 'completed', 'exit_code' => 0 }),
      'review' => check.call({ 'reviewer' => 'openai/codex', 'status' => 'completed', 'head' => HEAD })
    } }
    content = { 'human_comments' => packet(issue_comments: [issue_comment(3, 'ann', 'Applied.')]) }
    rendered = Shaka::Publication.description(PublicationRegressionTest.new(name).description_content(**content),
                                              nil, pull, Shaka::PublicationSettings.new(verdict:))

    assert_includes rendered, "## Verification\n\nValidation passed; local review completed at ccccccc.\n\n" \
                              "#{GAPS} 1 comment"
  end

  # A read taken before the latest push may count comments the author has since relabeled.
  def test_a_read_from_an_earlier_head_is_not_counted
    stale = packet(issue_comments: [issue_comment(3, 'ann', 'Applied.')]).merge('head' => 'd' * 40)

    refute_includes Shaka::Publication.description(
      PublicationRegressionTest.new(name).description_content('human_comments' => stale), nil, pull,
      Shaka::PublicationSettings.new(current: { 'pr_description.show_human_comments' => false })
    ), GAPS
  end

  # On a fork the PR author is an outside contributor, whose own words carry no agent label.
  def test_a_fork_s_author_comments_are_not_counted
    content = { 'human_comments' => packet(issue_comments: [issue_comment(3, 'ann', 'Thanks for the review.')]) }

    assert_equal 0, Shaka::VerificationGates.unlabeled(content, pull(fork: true))
  end

  # Without a head on either side there is no read of this revision to count from.
  def test_a_read_without_a_head_is_not_counted
    headless = packet(issue_comments: [issue_comment(3, 'ann', 'Applied.')]).except('head')
    content = { 'human_comments' => headless }

    assert_equal 0, Shaka::VerificationGates.unlabeled(content, pull.merge('head' => {}))
  end

  def test_a_reviewer_shortfall_and_unlabeled_comments_share_one_line
    settings = Shaka::PublicationSettings.new(reviewer_shortfall: SHORTFALL)
    content = { 'human_comments' => packet(issue_comments: [issue_comment(3, 'ann', 'Applied.')]) }
    rendered = Shaka::Publication.description(PublicationRegressionTest.new(name).description_content(**content),
                                              nil, pull, settings)

    assert_includes rendered, "#{GAPS} 1 of 2 configured reviewers completed; `openai` did not. " \
                              '1 comment from the PR author has no AI identity line'
    assert_equal 1, rendered.scan(GAPS).size
  end
end
