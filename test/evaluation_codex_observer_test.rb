# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_capture'
require_relative 'support/evaluation_capture_fixture'

class EvaluationCodexObserverTest < Minitest::Test
  include EvaluationCaptureFixture

  def test_controller_observes_events_before_the_child_can_finish
    events = []
    observer = lambda do |event|
      events << event
      File.write(File.join(@root, 'release'), 'go') if event.dig('native', 'type') == 'turn.started'
    end
    result = run_child(wait_for_controller, &observer)
    assert_equal 'completed', result.fetch('native_status')
    assert_equal result.fetch('events'), events
    refute result.fetch('command_capture_complete')
    refute result.fetch('terminal').key?('accepted_at')
  end

  def test_observations_cannot_be_rewritten_by_the_controller
    observer = ->(event) { assert_immutable(event) }
    result = run_child(write_stream, &observer)
    assert_equal '日本語 🌊', result.dig('terminal', 'text')
    assert_equal "sha256:#{Digest::SHA256.hexdigest(native_stream)}", result.fetch('stream_digest')
  end

  def test_observer_failure_stops_and_reaps_the_child_without_a_result
    body = "File.write('pid', Process.pid); STDOUT.sync=true; #{write_stream} sleep 30"
    observer = ->(_event) { raise 'controller readback failed' }
    assert_raises(IOError) { run_child(body, &observer) }
    refute_process(Integer(File.read(File.join(@root, 'pid'))))
    assert_operator File.size(private_log('stdout.jsonl')), :>, 0
  end

  def test_observer_time_counts_against_the_capture_deadline
    observer = ->(event) { sleep 0.15 if event.dig('native', 'type') == 'turn.started' }
    result = run_child(write_stream, seconds: 0.1, &observer)
    assert_equal 'timed_out', result.fetch('transport_status')
    assert_nil result.fetch('terminal')
  end

  def test_invalid_reader_observer_is_refused
    assert_raises(ArgumentError) do
      Shaka::Evaluation::CodexEvents.new(clock_id: 'test', observer: 'not callable')
    end
  end

  def test_reader_cannot_finish_after_observer_failure
    reader = Shaka::Evaluation::CodexEvents.new(clock_id: 'test', observer: ->(_) { raise 'readback failed' })
    assert_raises(IOError) { reader.receive(native_stream.lines.first) }
    assert_raises(IOError) { reader.finish(exit_code: 0) }
  end

  def test_invalid_native_order_cannot_trigger_a_controller_action
    events = []
    reader = Shaka::Evaluation::CodexEvents.new(clock_id: 'test', observer: ->(event) { events << event })
    assert_raises(IOError) { reader.receive(native_stream.lines[1]) }
    assert_empty events
  end

  def test_nested_native_tool_arguments_are_immutable
    observer = ->(event) { assert_paths_immutable(event) }
    reader = Shaka::Evaluation::CodexEvents.new(clock_id: 'test', observer:)
    native_stream.lines.first(2).each { reader.receive(it) }
    tool = { type: 'item.completed', item: { id: 'tool', type: 'mcp_tool_call', arguments: { paths: ['original'] } } }
    reader.receive(JSON.generate(tool))
    result = reader.finish(exit_code: 0)
    assert_equal ['original'], result.fetch('events').last.dig('native', 'item', 'arguments', 'paths')
  end

  private

  def assert_paths_immutable(event)
    paths = event.dig('native', 'item', 'arguments', 'paths')
    return unless paths

    assert_raises(FrozenError) { paths << 'extra' }
    assert_raises(FrozenError) { paths.first.replace('different') }
  end

  def wait_for_controller
    lines = native_stream.lines
    "STDOUT.sync=true; print #{lines.first(2).join.dump}; " \
      "sleep 0.01 until File.exist?('release'); print #{lines.drop(2).join.dump}"
  end

  def assert_immutable(event)
    assert_predicate event, :frozen?
    assert_predicate event.fetch('native'), :frozen?
    assert_predicate event.dig('native', 'type'), :frozen?
    assert_raises(FrozenError) { event['received_at'] = 0 }
    return unless event.dig('native', 'type') == 'item.completed'

    assert_raises(FrozenError) { event.dig('native', 'item', 'text').replace('different') }
  end
end
