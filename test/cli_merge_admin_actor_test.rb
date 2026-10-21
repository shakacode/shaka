# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# Runs the merge command against immutable policy with GitHub submission stubbed.
class CliMergeAdminActorTest < Minitest::Test
  include CliMergeFixture

  def test_admin_actor_can_merge_without_account_configuration
    with_merge_repository do |root, ref, mutation|
      output, error, status = run_merge(root, ref, mutation)

      assert_predicate status, :success?, error
      assert_equal 'MERGED', JSON.parse(output)['state']
      assert_path_exists mutation
      assert_equal 'Reason.', JSON.parse(File.read(mutation)).dig('variables', 'body')
    end
  end

  def test_unprotected_branch_refuses_an_unconfirmed_merge
    with_merge_repository do |root, ref, mutation|
      _, error, status = run_merge(root, ref, mutation, env: { 'NO_REQUIRED_CHECKS' => '1' })

      refute_predicate status, :success?
      assert_match(/--empty-checks-confirmed-head/, error)
      refute_path_exists mutation
    end
  end

  def test_unprotected_branch_merges_the_head_the_user_confirmed
    with_merge_repository do |root, ref, mutation|
      output, error, status = run_merge(root, ref, mutation, '--empty-checks-confirmed-head', HEAD,
                                        env: { 'NO_REQUIRED_CHECKS' => '1' })

      assert_predicate status, :success?, error
      assert_equal HEAD, JSON.parse(output)['empty_required_checks_confirmed_head']
      assert_path_exists mutation
    end
  end
end
