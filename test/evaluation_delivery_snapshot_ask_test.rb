# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_snapshot'
require_relative '../eval/lib/shaka/evaluation/delivery_ask'
require_relative 'support/evaluation_snapshot_fixture'
require_relative 'support/evaluation_ask_fixture'

class EvaluationDeliverySnapshotAskTest < Minitest::Test
  include EvaluationSnapshotFixture

  def protocol = Object.new.extend(EvaluationAskFixture)

  def protocol_snapshot(rows)
    row = pull
    row.dig('data', 'repository', 'pullRequest', 'files', 'nodes')[0]['path'] = 'lib/code.rb'
    capture([row, rows, blobs, row])
  end

  def graded(rows = checks)
    snapshot = protocol_snapshot(rows)
    packet = protocol.evidence.merge(snapshot.slice('pull', 'checks', 'changed_files'))
    accepted = snapshot.fetch('observed_at') + 1
    packet['terminal'].merge!('received_at' => accepted, 'accepted_at' => accepted)
    packet['current_walkthrough']['readback_finished_at'] = accepted + 1
    protocol.grader.call(packet)
  end

  def test_snapshot_integrates_with_the_six_assertions_using_synthetic_other_inputs
    assert graded.fetch('passed')
  end

  def test_native_pending_check_fails_the_ask_contract
    row = checks
    row['check_runs'][0].merge!('status' => 'in_progress', 'conclusion' => nil)
    result = graded(row)
    refute result.fetch('passed')
    refute result.fetch('assertions').fetch('required_checks')
  end
end
