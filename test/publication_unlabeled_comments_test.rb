# frozen_string_literal: true

require_relative 'publication_human_comments_test'

# A comment without an identity line reads as the person's. An agent posts under the author's
# login, so its `gh` reply looks the same; `shaka resolve` refuses that reply, and nothing can
# tell the two apart well enough to warn about it.
class PublicationUnlabeledCommentsTest < Minitest::Test
  include HumanCommentsFixture

  # https://github.com/shakacode/shaka/pull/995#issuecomment-6541201159
  def test_the_author_s_plain_comment_is_listed_and_adds_no_setup_gap
    content = { 'human_comments' => packet(issue_comments: [issue_comment(3, 'ann', 'This reads as a warning')]) }
    rendered = Shaka::Publication.description(PublicationRegressionTest.new(name).description_content(**content), nil,
                                              pull.merge('author_association' => 'MEMBER'),
                                              Shaka::PublicationSettings.new(verdict: routine_verdict))

    assert_includes rendered, 'This reads as a warning'
    assert_includes rendered, "## Verification\n\nValidation passed; local review completed at ccccccc."
    refute_includes rendered, Shaka::VerificationGates::GAPS
  end

  private

  def routine_verdict
    check = ->(result) { [{ 'status' => 'bound', 'original' => result }] }
    { 'status' => 'ready', 'head' => HEAD, 'checks' => {
      'validation' => check.call({ 'command' => 'validate', 'status' => 'completed', 'exit_code' => 0 }),
      'review' => check.call({ 'reviewer' => 'openai/codex', 'status' => 'completed', 'head' => HEAD })
    } }
  end
end
