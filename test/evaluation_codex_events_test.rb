# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_events'
require_relative '../eval/lib/shaka/evaluation/delivery_ask'
require_relative 'support/evaluation_ask_fixture'
require_relative 'support/evaluation_codex_fixture'

class EvaluationCodexEventsTest < Minitest::Test
  include EvaluationAskFixture
  include EvaluationCodexFixture

  def test_native_terminal_has_host_receipt_time_and_no_controller_acceptance
    terminal = completed_capture.fetch('terminal')
    assert_equal 'Final answer', terminal.fetch('text')
    assert_equal 5, terminal.fetch('received_at')
    refute terminal.key?('accepted_at')
    assert_equal 'assistant_terminal', terminal.fetch('type')
  end

  def test_stream_receipt_keeps_native_identity_order_and_digest
    result = completed_capture
    assert_equal 'native-thread', result.fetch('thread_id')
    assert_equal 'completed', result.fetch('native_status')
    assert_equal 'controller-lifetime', result.fetch('clock_id')
    assert_equal([1, 2, 3, 4, 5, 6], result.fetch('events').map { it.fetch('ordinal') })
  end

  def test_stream_digest_covers_the_original_bytes
    result = completed_capture
    assert_equal "sha256:#{Digest::SHA256.hexdigest(@lines.join)}", result.fetch('stream_digest')
    assert_equal @lines.join.bytesize, result.fetch('byte_count')
  end

  def test_native_tool_text_is_retained_without_a_completeness_claim
    result = completed_capture
    assert_equal 'echo SHAKA_NEEDS_APPROVAL', result.fetch('events')[2].dig('native', 'item', 'command')
    refute result.fetch('command_capture_complete')
  end

  def test_only_completed_agent_messages_supply_terminal_text
    start
    emit('item.completed', item: { id: 'tool', type: 'command_execution',
                                   aggregated_output: 'SHAKA_NEEDS_APPROVAL', status: 'completed' })
    emit('item.completed', item: { id: 'thought', type: 'reasoning', text: 'SHAKA_NEEDS_APPROVAL' })
    emit('turn.completed')
    assert_nil @reader.finish(exit_code: 0).fetch('terminal')
  end

  def test_last_message_wins_and_native_timestamps_do_not_override_host_receipt_time
    start
    emit_message('Earlier commentary')
    emit('item.completed', item: { id: 'final', type: 'agent_message', text: '日本語 🌊' }, received_at: -100)
    emit('turn.completed')
    result = @reader.finish(exit_code: 0)
    assert_equal '日本語 🌊', result.fetch('terminal').fetch('text')
    assert_equal 4, result.fetch('terminal').fetch('received_at')
  end

  def test_an_empty_final_message_cannot_promote_an_earlier_one
    start
    emit_message('Earlier commentary')
    emit('item.completed', item: { id: 'empty', type: 'agent_message', text: '' })
    emit('turn.completed')
    assert_nil @reader.finish(exit_code: 0).fetch('terminal')
  end

  def test_process_and_native_completion_are_both_needed
    [nil, 1, 0].each do |exit_code|
      reset_capture
      start
      emit_message('Answer')
      emit('turn.completed') unless exit_code&.zero?
      result = @reader.finish(exit_code: exit_code)
      assert_nil result.fetch('terminal')
      assert_equal(exit_code == 1 ? 'failed' : 'incomplete', result.fetch('native_status'))
    end
  end

  def test_native_failures_preserve_partial_tool_evidence_without_a_terminal
    start
    emit('item.started', item: { id: 'tool', type: 'mcp_tool_call', server: 'native', tool: 'lookup' })
    emit_message('Answer')
    emit('turn.failed', error: { message: 'native failure' })
    result = @reader.finish(exit_code: 1)
    assert_equal 'failed', result.fetch('native_status')
    assert_nil result.fetch('terminal')
    assert_equal 'lookup', result.fetch('events')[2].dig('native', 'item', 'tool')
  end

  def test_error_events_do_not_become_success_even_with_a_zero_exit
    emit('error', message: 'native failure')
    assert_equal 'failed', @reader.finish(exit_code: 0).fetch('native_status')
  end

  def test_unqualified_capture_keeps_the_existing_ask_no_merge_assertion_false
    result = grader(clock_id: 'controller-lifetime').call(captured_packet)
    refute result.fetch('assertions').fetch('no_merge')
    assert result.fetch('assertions').except('no_merge').values.all?(true)
    refute result.fetch('passed')
  end

  private

  def captured_packet
    @now = 6
    start
    emit_message(evidence.fetch('terminal').fetch('text'))
    emit('turn.completed')
    capture = @reader.finish(exit_code: 0)
    evidence.merge('clock_id' => capture.fetch('clock_id'),
                   'terminal' => capture.fetch('terminal').merge('accepted_at' => 11),
                   'command_capture_complete' => capture.fetch('command_capture_complete'))
  end
end
