# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_events'
require_relative 'support/evaluation_codex_fixture'

class EvaluationCodexEventFailuresTest < Minitest::Test
  include EvaluationCodexFixture

  def test_invalid_json_and_duplicate_keys_poison_capture_without_echoing_content
    ['[]', '{}', '{"type":', '{"type":"error","type":"thread.started"}',
     '{"type":"thread.started","thread_id":"one","thread_id":"two"}',
     "{\"type\":\"error\"}\n{\"type\":\"error\"}\n"].each do |line|
      reset_capture
      error = assert_raises(IOError) { @reader.receive(line) }
      refute_includes error.message, line
      assert_raises(IOError) { @reader.finish(exit_code: 0) }
    end
  end

  def test_a_turn_requires_a_thread_and_unknown_events_poison_capture
    [-> { emit('turn.started') }, -> { emit('future.event') }].each do |scenario|
      reset_capture
      assert_raises(IOError, &scenario)
      assert_raises(IOError) { @reader.finish(exit_code: 0) }
    end
  end

  def test_a_second_thread_and_items_after_turn_end_are_refused
    start
    assert_raises(IOError) { emit('thread.started', thread_id: 'other') }
    reset_capture
    start
    emit('turn.completed')
    assert_raises(IOError) { emit_message('late') }
  end

  def test_item_identity_cannot_change_type_or_restart
    [-> { emit('item.started', item: { id: 'same', type: 'command_execution' }) },
     -> { emit('item.completed', item: { id: 'same', type: 'agent_message', text: 'forged' }) }].each do |change|
      reset_capture
      start
      emit('item.started', item: { id: 'same', type: 'command_execution' })
      assert_raises(IOError, &change)
    end
  end

  def test_completed_item_ids_cannot_be_reused_and_finish_seals_the_stream
    start
    emit_message('Answer')
    assert_raises(IOError) { emit_message('Changed') }
    reset_capture
    @reader.finish(exit_code: nil)
    assert_raises(IOError) { emit('thread.started', thread_id: 'late') }
    assert_raises(IOError) { @reader.finish(exit_code: 0) }
  end

  def test_broken_clocks_cannot_supply_receipt_order
    [Float::NAN, Float::INFINITY, -1, '1'].each do |value|
      reset_capture
      @now = value
      assert_raises(IOError) { @reader.receive("{\"type\":\"error\"}\n") }
    end
    reset_capture
    start
    @now = 0
    assert_raises(IOError) { @reader.receive("{\"type\":\"error\"}\n") }
  end

  def test_a_valid_but_oversized_event_is_refused
    line = "#{JSON.generate(type: 'error', message: 'x' * Shaka::Evaluation::CodexEvents::MAX_LINE)}\n"
    assert_raises(IOError) { @reader.receive(line) }
  end

  def test_clock_exceptions_also_poison_capture
    calls = 0
    clock = lambda do
      calls += 1
      raise 'clock failed' if calls == 1

      calls
    end
    @reader = Shaka::Evaluation::CodexEvents.new(clock_id: 'lifetime', clock: clock)
    assert_raises(IOError) { @reader.receive("{\"type\":\"error\"}\n") }
    assert_raises(IOError) { @reader.finish(exit_code: nil) }
  end

  def test_total_bytes_and_event_count_are_bounded_through_the_public_receiver
    line = "#{JSON.generate(type: 'error', message: 'x' * 131_072)}\n"
    Shaka::Evaluation::CodexEvents::MAX_BYTES.div(line.bytesize).times { @reader.receive(line) }
    assert_raises(IOError) { @reader.receive(line) }
    reset_capture
    Shaka::Evaluation::CodexEvents::MAX_EVENTS.times { @reader.receive("{\"type\":\"error\"}\n") }
    assert_raises(IOError) { @reader.receive("{\"type\":\"error\"}\n") }
  end
end
