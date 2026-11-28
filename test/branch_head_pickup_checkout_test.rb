# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'
require 'shaka/branch_head/pickup_checkout'

# Whether origin pushes to the PR's head repository before a pickup claims the PR.
class PickupCheckoutTest < Minitest::Test
  include BranchHeadFixture

  def test_origin_must_push_to_the_pr_head_repository
    git(@task, 'remote', 'set-url', '--push', 'origin', 'https://github.example.com/Base/Repo.git')

    assert_true pushes_to?('base/repo')
    assert_false pushes_to?('mirror/repo')
  end

  def test_a_push_url_that_names_no_repository_never_matches
    assert_false pushes_to?('base/repo')
  end

  private

  def pushes_to?(repository)
    Shaka::BranchHead::PickupCheckout.pushes_to?(@task, 'branch' => BRANCH,
                                                        'repository' => repository)
  end
end
