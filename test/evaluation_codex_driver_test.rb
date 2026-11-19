# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_driver'
require_relative 'support/evaluation_codex_driver_fixture'
require_relative 'support/evaluation_deadline_clock'

class EvaluationCodexDriverTest < Minitest::Test
  include EvaluationCodexDriverFixture
  include EvaluationDeadlineClock

  def test_observed_head_transitions_run_once_each_and_preserve_private_receipts
    result = run_driver(sequence: [HEAD, 'c' * 40, 'c' * 40, HEAD])
    expected = [[HEAD, 1, 1], ['c' * 40, 2, 2], [HEAD, 3, 3]]
    assert_equal(expected, result.fetch('verifications').map { it.values_at('head', 'attempt', 'executions') })
    assert_journal(result.fetch('verifications'))
  end

  def test_raw_capture_and_ledger_remain_private_and_unqualified
    result = run_driver
    %w[. ledger.jsonl capture/stdout.jsonl].each do |path|
      assert_equal 0, File.stat(File.join(@output, path)).mode & 0o077
    end
    refute result.dig('capture', 'command_capture_complete')
    refute result.dig('capture', 'terminal').key?('accepted_at')
  end

  def test_command_text_cannot_select_the_repository_head_or_verifier
    result = run_driver(sequence: [HEAD, HEAD], verifier: "puts ENV.fetch('SHAKA_EVAL_HEAD')")
    assert_equal([HEAD], result.fetch('verifications').map { it.fetch('head') })
    assert_equal "#{HEAD}\n", File.read(File.join(@output, 'verification-1/output.log'))
    assert_equal(['COMMENT'], posts.map { it.fetch('request').fetch('event') })
  end

  def test_nonzero_result_is_recorded_as_fail_without_retry_for_unchanged_head
    result = run_driver(sequence: [HEAD, HEAD], verifier: 'exit 7')
    assert_equal 1, posts.size
    assert_includes result.dig('verifications', 0, 'receipt', 'review', 'body'), 'driver-verification: FAIL'
  end

  def test_ambiguous_write_aborts_capture_retains_attempt_and_never_retries
    File.write(File.join(@directory, 'mode'), 'ambiguous_post')
    assert_raises(IOError) { run_driver(sequence: [HEAD, HEAD]) }
    assert_equal 1, posts.size
    assert_equal(%w[started failed], ledger.map { it.fetch('state') })
    assert_raises(ArgumentError) { run_driver(writer: @writer) }
    assert_equal 1, posts.size
  end

  def test_new_head_over_attempt_bound_is_refused_without_second_execution
    assert_raises(IOError) { run_driver(sequence: [HEAD, 'c' * 40], max_attempts: 1) }
    assert_equal 1, posts.size
    refute_path_exists File.join(@output, 'verification-2')
  end

  def test_shared_deadline_stops_verification_and_reaps_its_process
    path = File.join(@directory, 'pid')
    assert_raises(IOError) do
      expire_deadlines_when(-> { File.size?(path) }) do
        run_driver(verifier: "File.write('pid', Process.pid); sleep 30", seconds: 60)
      end
    end
    pid = Integer(File.read(path))
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
    assert_empty posts
    assert_equal 'failed', ledger.last.fetch('state')
  end

  def test_prebuffered_terminal_keeps_its_receipt_before_the_driver_post
    @buffered = true
    result = run_driver
    assert_operator result.dig('capture', 'terminal', 'received_at'), :<,
                    result.dig('verifications', 0, 'post_completed_at')
  end

  def test_head_discovery_shares_the_capture_deadline
    File.write(File.join(@directory, 'mode'), 'slow_head')
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(IOError) { run_driver(seconds: 0.4) }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator elapsed, :<, 1.5
    assert_empty posts
    refute_path_exists File.join(@output, 'verification-1')
  end

  private

  def assert_journal(entries)
    assert_equal(%w[started completed started completed started completed], ledger.map { it.fetch('state') })
    assert_equal(entries, ledger.filter_map { it['entry'] })
  end
end
