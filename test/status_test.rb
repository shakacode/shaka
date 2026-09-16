# frozen_string_literal: true

require_relative 'github_helper'
require 'shaka/status'

class StatusTest < Minitest::Test
  include GitHubHelper

  def test_status_reports_the_snapshot_with_required_check_states
    checks = [{ 'name' => 'validate', 'state' => 'PENDING', 'bucket' => 'pending' }]
    result = Shaka::Status.new(client(snapshot_response, response(checks, status: 8), snapshot_response)).call
    assert_equal HEAD, result['headRefOid']
    assert_equal checks, result['requiredChecks']
  end

  def test_status_reports_absent_required_checks_without_failing
    unavailable = ['', 'no required checks reported', STATUS.new(1)]
    result = Shaka::Status.new(client(snapshot_response, unavailable, snapshot_response)).call
    assert_nil result['requiredChecks']
    assert_includes result['requiredChecksUnavailable'], 'unavailable'
  end

  def test_status_rejects_a_head_that_changed_while_reading
    checks = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
    status = Shaka::Status.new(client(snapshot_response, response(checks), snapshot_response(head: 'b' * 40)))
    error = assert_raises(Shaka::Error) { status.call }
    assert_includes error.message, 'head changed'
  end
end
