# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_approval'
require_relative '../eval/lib/shaka/evaluation/codex_events'
require_relative 'support/evaluation_ask_fixture'

class EvaluationCodexApprovalTest < Minitest::Test
  include EvaluationAskFixture

  def test_accepts_final_native_message_without_mutating_capture_or_granting_complete_capture
    result = driver_result
    original = Marshal.dump(result)
    accepted = accept(result)
    assert_in_delta(20.0, accepted.dig('terminal', 'accepted_at'))
    assert_equal result.dig('capture', 'terminal', 'text'), accepted.dig('terminal', 'text')
    assert_equal original, Marshal.dump(result)
    refute result.dig('capture', 'command_capture_complete')
  end

  def test_acceptance_alone_cannot_pass_delivery_grading
    packet = evidence.merge(accept(driver_result)).merge('command_capture_complete' => false)
    assert grader.call(packet).fetch('assertions').fetch('terminal')
    refute grader.call(packet).fetch('passed')
  end

  def test_readback_can_finish_after_terminal_receipt_but_before_acceptance
    result = driver_result(received: 6.0)
    accepted = accept(result)
    assert_in_delta(6.0, accepted.dig('terminal', 'received_at'))
    assert_operator accepted.dig('terminal', 'accepted_at'), :>, 7.0
  end

  def test_pre_post_or_prebuffered_terminal_is_not_retimed
    [4.0, 5.0].each do |time|
      assert_raises(IOError) { accept(driver_result(received: time)) }
    end
  end

  def test_checks_and_walkthrough_cannot_be_queued
    assert_raises(IOError) { accept(driver_result, checks: [check.merge('observed_at' => 10.0)]) }
    late = evidence.fetch('walkthrough').merge('readback_finished_at' => 10.0)
    assert_raises(IOError) { accept(driver_result, walkthrough: late) }
  end

  def test_missing_or_duplicate_prerequisites_cannot_accept
    assert_raises(IOError) { accept(driver_result, changed_files: {}) }
    assert_raises(IOError) { accept(driver_result, checks: [check, check]) }
  end

  def test_missing_failed_or_wrong_actor_driver_receipt_cannot_accept
    result = driver_result
    result['verifications'] << verification(2, 'FAIL').merge('clock_id' => 'process-1',
                                                             'verification' => { 'clock_id' => 'process-1' })
    assert_raises(IOError) { accept(result) }
    reject_result ['verifications'] => [],
                  ['verifications', 0, 'receipt', 'review', 'author', 'login'] => 'fixture-agent',
                  ['verifications', 0, 'receipt', 'review', 'commit', 'oid'] => 'b' * 40,
                  ['verifications', 0, 'receipt', 'review', 'body_digest'] => 'sha256:wrong',
                  ['verifications', 0, 'receipt', 'readback_finished_at'] => 20.0
  end

  def test_only_final_exact_marker_can_accept
    result = driver_result
    result['capture']['terminal']['text'] += 'Afterword'
    assert_raises(IOError) { accept(result) }
    reject_result %w[capture terminal type] => 'tool_output',
                  %w[capture terminal text] => "SHAKA_NEEDS_APPROVAL head=#{HEAD} walkthrough=11"
  end

  def test_failed_capture_mixed_clocks_and_future_times_cannot_accept
    reject_result %w[capture transport_status] => 'timed_out', %w[capture native_status] => 'incomplete',
                  %w[capture exit_code] => 1, %w[capture clock_id] => 'other',
                  ['verifications', 0, 'clock_id'] => 'other',
                  ['verifications', 0, 'verification', 'clock_id'] => 'other',
                  %w[capture turn_ended_at] => 9.0, %w[capture observed_at] => 21.0,
                  %w[capture terminal received_at] => Float::NAN
  end

  def test_one_attempt_even_after_refusal_and_missing_capture_is_unavailable
    writer = Shaka::Evaluation::CodexApproval.new(plan, clock: -> { 20.0 })
    assert_raises(IOError) { accept({}, writer:) }
    assert_raises(ArgumentError) { accept(driver_result, writer:) }
  end

  private

  def plan
    { 'repository' => REPOSITORY, 'number' => 1, 'head' => HEAD, 'machine_actor' => 'fixture-agent',
      'driver_actor' => 'fixture-driver', 'required_checks' => ['validate'], 'clock_id' => 'process-1' }
  end

  def driver_result(received: 10.0)
    times = [0.0, 1.0, received, 11.0, 12.0]
    reader = Shaka::Evaluation::CodexEvents.new(clock_id: 'process-1', clock: -> { times.shift })
    events = [{ type: 'thread.started', thread_id: 'native-thread' }, { type: 'turn.started' },
              { type: 'item.completed', item: { id: 'native-final', type: 'agent_message',
                                                text: evidence.dig('terminal', 'text') } },
              { type: 'turn.completed' }]
    events.each { reader.receive("#{JSON.generate(it)}\n") }
    capture = reader.finish(exit_code: 0).merge('transport_status' => 'completed', 'exit_code' => 0)
    entry = verification.merge('clock_id' => 'process-1', 'verification' => { 'clock_id' => 'process-1' })
    { 'capture' => capture, 'verifications' => [entry] }
  end

  def accept(result, writer: Shaka::Evaluation::CodexApproval.new(plan, clock: -> { 20.0 }), **overrides)
    options = evidence.slice('checks', 'walkthrough', 'changed_files').transform_keys(&:to_sym).merge(overrides)
    writer.accept(driver_result: result, **options)
  end

  def reject_result(changes)
    changes.each do |path, value|
      result = driver_result
      container = path[0...-1].reduce(result) { |row, key| row.fetch(key) }
      container[path.last] = value
      assert_raises(IOError, path.inspect) { accept(result) }
    end
  end
end
