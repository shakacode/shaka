# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_events'
require_relative 'support/evaluation_codex_fixture'

class EvaluationCodexItemsTest < Minitest::Test
  include EvaluationCodexFixture

  def test_unfinished_command_withholds_terminal_after_turn_completion
    assert_incomplete_tool('command_execution')
  end

  def test_unfinished_mcp_call_withholds_terminal_after_turn_completion
    assert_incomplete_tool('mcp_tool_call')
  end

  def test_updated_tools_still_need_a_completion_event
    start
    emit('item.updated', item: { id: 'tool', type: 'command_execution' })
    emit_message('Answer')
    emit('turn.completed')
    assert_equal 'incomplete', @reader.finish(exit_code: 0).fetch('native_status')
  end

  def test_completed_tools_allow_a_terminal_candidate
    start
    emit('item.started', item: { id: 'tool', type: 'command_execution' })
    emit('item.completed', item: { id: 'tool', type: 'command_execution', status: 'failed' })
    emit_message('Answer')
    emit('turn.completed')
    result = @reader.finish(exit_code: 0)
    assert_equal 'completed', result.fetch('native_status')
    assert_equal 'Answer', result.fetch('terminal').fetch('text')
    refute result.fetch('command_capture_complete')
  end

  private

  def assert_incomplete_tool(type)
    start
    emit('item.started', item: { id: 'tool', type: type })
    emit_message('Answer')
    emit('turn.completed')
    result = @reader.finish(exit_code: 0)
    assert_equal 'incomplete', result.fetch('native_status')
    assert_nil result.fetch('terminal')
    assert_equal type, result.fetch('events')[2].dig('native', 'item', 'type')
    refute result.fetch('command_capture_complete')
  end
end
