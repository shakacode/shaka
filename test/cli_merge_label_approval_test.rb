# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# The merge command reads the merge-approved label before Auto's gates when --label-approval chose Auto.
class CliMergeLabelApprovalTest < Minitest::Test
  include CliMergeFixture

  def test_a_pr_without_the_label_is_handed_back_under_ask
    with_merge_repository do |root, ref, mutation|
      _, error, status = run_merge(root, ref, mutation, '--auto', '--label-approval', env: { 'PR_LABELS' => 'bug' })

      refute_predicate status, :success?
      assert_match(/merge-approved does not choose Auto: the PR does not carry it. Hand the PR back under Ask/, error)
      refute_path_exists mutation
    end
  end
end
