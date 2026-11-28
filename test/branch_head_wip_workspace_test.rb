# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_ownership_fixture'

# How release and pickup use the checkout WIP Details names as Workspace.
class BranchHeadWipWorkspaceTest < Minitest::Test
  include BranchHeadOwnershipFixture

  def test_release_counts_unpushed_work_only_in_the_wip_workspace
    sha = push_task('first')
    commit(@task, 'unpushed')
    with_workspace(@task) { release(@task, 'origtag', sha) }

    assert_includes last_comment, "in the owner's checkout: unpushed commits: 1"
  end

  def test_release_from_another_checkout_reports_unknown
    sha = push_task('first')
    with_workspace(File.join(@dir, 'elsewhere')) { release(@task, 'origtag', sha) }

    assert_includes last_comment, 'UNKNOWN: released from a checkout other than the WIP Details Workspace'
  end

  def test_pickup_refuses_the_previous_owners_checkout
    released_task
    posted = @github.comments.size
    error = assert_raises(Shaka::Error) { with_workspace(@task) { pickup(@task, 'newtag') } }

    assert_includes error.message, "previous owner's checkout"
    assert_equal posted, @github.comments.size
  end

  private

  # WIP Details naming path as Workspace, as `description` publishes it.
  def with_workspace(path)
    original = Shaka::Handoff::WipNote.method(:value)
    Shaka::Handoff::WipNote.define_singleton_method(:value) { |_body, field| path if field == 'workspace' }
    yield
  ensure
    Shaka::Handoff::WipNote.define_singleton_method(:value, original)
  end
end
