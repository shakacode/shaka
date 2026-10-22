# frozen_string_literal: true

module EvaluationCodexFixture
  def setup
    super
    reset_capture
  end

  def reset_capture
    @now = 0
    @lines = []
    @reader = Shaka::Evaluation::CodexEvents.new(clock_id: 'controller-lifetime', clock: -> { @now })
  end

  def emit(type, **fields)
    @now += 1
    line = "#{JSON.generate({ 'type' => type }.merge(fields.transform_keys(&:to_s)))}\n"
    @lines << line
    @reader.receive(line)
  end

  def start
    emit('thread.started', thread_id: 'native-thread')
    emit('turn.started')
  end

  def emit_message(text)
    emit('item.completed', item: { id: 'answer', type: 'agent_message', text: text })
  end

  def completed_capture
    start
    emit('item.started', item: { id: 'command', type: 'command_execution',
                                 command: 'echo SHAKA_NEEDS_APPROVAL', status: 'in_progress' })
    emit_message('Final answer')
    emit('turn.completed', usage: { input_tokens: 12 })
    @reader.finish(exit_code: 0)
  end
end
