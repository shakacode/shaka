# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# The merge command reads walkthrough.publish from trusted settings and this account's request comment.
class CliMergeWalkthroughTest < Minitest::Test
  include CliMergeFixture

  REQUEST = [{ 'user' => { 'login' => 'agent' },
               'body' => "<!-- shaka:reply:walkthrough-request -->\nAsked for a walkthrough." }].freeze

  def test_merges_without_a_walkthrough_nobody_asked_for
    with_merge_repository do |root, ref, mutation|
      _, error, status = run_merge_without_walkthrough(root, ref, mutation, *CONFIRMED)

      assert_predicate status, :success?, error
      assert_path_exists mutation
    end
  end

  def test_a_repository_that_always_publishes_one_refuses_a_merge_without_it
    with_merge_repository(walkthrough: { 'publish' => 'always' }) do |root, ref, mutation|
      assert_refused(*run_merge_without_walkthrough(root, ref, mutation, *CONFIRMED), mutation)
    end
  end

  def test_a_recorded_request_refuses_a_merge_without_it
    with_merge_repository do |root, ref, mutation|
      env = { 'PR_COMMENTS' => JSON.generate(REQUEST) }
      assert_refused(*run_merge_without_walkthrough(root, ref, mutation, *CONFIRMED, env:), mutation)
    end
  end

  private

  def assert_refused(_output, error, status, mutation)
    refute_predicate status, :success?
    assert_match(/walkthrough is due/, error)
    refute_path_exists mutation
  end
end
