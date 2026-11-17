# frozen_string_literal: true

require_relative 'local_review_publish_cleanup_test'

# A fresh ledger, such as one a base change forces, leaves the earlier ledger's comment visible;
# the agent folds it by selecting it once its findings are carried forward.
class LocalReviewCollapseSelectionTest < LocalReviewPublishCleanupSupport
  def test_selecting_an_earlier_ledgers_comment_folds_it_behind_the_current_one
    github = two_ledgers

    status, result = select(github, current: 2, superseded: [1])

    assert_equal [0, [1], []], [status, result.fetch('collapsed'), result.fetch('unavailable')]
    body = comment(github, 1)
    assert_includes body, "#{Shaka::LocalReviewHistory::MARKER} https://github.com/o/r/pull/7#issuecomment-2"
    assert_equal "REVIEWED #{EARLIER} BY openai/codex EFFORT UNKNOWN FINDINGS 1", body.lines.last.strip
    refute_includes comment(github, 2), Shaka::LocalReviewHistory::MARKER
  end

  def test_the_bare_command_folds_an_earlier_ledgers_comment_too
    github = two_ledgers

    status, result = collapse(github)

    assert_equal [0, [1]], [status, result.fetch('collapsed')]
  end

  def test_a_selected_comment_for_the_current_commit_stays_visible_and_is_reported
    github = Timeline.new
    [%w[aaaaaaaaaaaa], %w[bbbbbbbbbbbb]].each do |(id)|
      assert_equal 0, publish(github, { 'id' => id, 'rounds' => [clean_round] }).first
    end

    status, result = select(github, current: 2, superseded: [1])

    assert_equal [1, []], [status, result.fetch('collapsed')]
    assert_includes result.fetch('unavailable').join, 'Comment 1 was not folded'
    assert_empty github.edits
  end

  def test_an_evidence_comment_selected_behind_a_review_comment_is_reported
    github = two_ledgers
    github.add_evidence(70)

    status, result = select(github, current: 2, superseded: [1, 70])

    assert_equal [1, [1]], [status, result.fetch('collapsed')]
    assert_includes result.fetch('unavailable').join, 'Comment 70 was not folded'
    refute_includes comment(github, 70), 'Superseded'
  end

  def test_a_current_comment_that_is_not_a_visible_review_comment_folds_nothing
    github = two_ledgers

    status, result = select(github, current: 1, superseded: [2])

    assert_equal [1, []], [status, result.fetch('collapsed')]
    assert_includes result.fetch('unavailable').join, 'Comment 1'
    assert_empty github.edits
  end

  private

  def clean_round = round(HEAD, findings: [], report: report(HEAD, findings: 0))

  def two_ledgers
    github = Timeline.new
    publish_previous_ledger(github)
    assert_equal 0, publish(github, { 'rounds' => [clean_round] }).first
    github.edits.clear
    def github.add_evidence(id)
      @comments[id] = { 'id' => id, 'user' => { 'login' => viewer_login }, 'created_at' => '2026-10-04T00:00:00Z',
                        'issue_url' => 'https://api.github.com/repos/o/r/issues/7',
                        'body' => "🤖 AGENT · OpenAI · gpt · high\n\nScreenshot." }
    end
    github
  end

  def select(github, current:, superseded:)
    arguments = ['--current', current.to_s, *superseded.flat_map { |id| ['--superseded', id.to_s] }]
    collapse(github, *arguments)
  end

  def collapse(github, *arguments)
    output, = capture_io do
      @status = Shaka::LocalReview.run(['collapse', 'o/r', '7', *arguments], github:)
    end
    [@status, JSON.parse(output)]
  end
end
