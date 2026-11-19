# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_driver'
require_relative 'support/evaluation_codex_driver_fixture'
require_relative 'support/evaluation_deadline_clock'

class EvaluationCodexDriverFailureTest < Minitest::Test
  include EvaluationCodexDriverFixture
  include EvaluationDeadlineClock

  def test_failed_native_capture_cannot_return_a_completed_verifier_as_an_aggregate
    @mode = 'failed'
    assert_raises(IOError) { run_driver }
    assert_equal 'completed', ledger.last.fetch('state')
    assert_equal 1, posts.size
  end

  def test_incomplete_native_capture_refuses_an_aggregate_but_retains_private_receipts
    @mode = 'incomplete'
    assert_raises(IOError) { run_driver }
    assert_equal 'completed', ledger.last.fetch('state')
    assert_path_exists File.join(@output, 'capture/stdout.jsonl')
  end

  def test_expired_capture_cannot_return_earlier_verification_receipts
    @mode = 'hang'
    path = File.join(@output, 'ledger.jsonl')
    verified = -> { File.exist?(path) && File.read(path).include?('"completed"') }
    assert_raises(IOError) { expire_deadlines_when(verified) { run_driver(seconds: 60) } }
    assert_equal 'completed', ledger.last.fetch('state')
  end
end
