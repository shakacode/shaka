# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# The merge command applies the trusted merge.hold_labels, not only the shipped default.
class CliMergeHoldTest < Minitest::Test
  include CliMergeFixture

  def test_a_configured_hold_label_refuses_the_merge
    with_merge_repository(merge_policy.merge('hold_labels' => ['do-not-merge'])) do |root, ref, mutation|
      _, error, status = run_merge(root, ref, mutation, env: { 'PR_LABELS' => 'bug,Do-Not-Merge' })

      refute_predicate status, :success?
      assert_match(/hold label "Do-Not-Merge" \(merge\.hold_labels\)/, error)
      refute_path_exists mutation
    end
  end

  def test_a_label_the_repository_does_not_list_merges
    with_merge_repository(merge_policy.merge('hold_labels' => ['do-not-merge'])) do |root, ref, mutation|
      _, error, status = run_merge(root, ref, mutation, env: { 'PR_LABELS' => 'hold' })

      assert_predicate status, :success?, error
      assert_path_exists mutation
    end
  end
end
