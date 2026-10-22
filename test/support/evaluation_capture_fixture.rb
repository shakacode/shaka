# frozen_string_literal: true

require 'rbconfig'
require 'tmpdir'
require 'fileutils'

module EvaluationCaptureFixture
  def setup
    super
    skip 'POSIX process groups required' unless Process.respond_to?(:fork)
    @root = Dir.mktmpdir('codex-capture-test-')
    @directory = File.join(@root, 'capture')
    @capture = Shaka::Evaluation::CodexCapture.new(environment: { 'CAPTURE_MARKER' => 'selected' })
  end

  def teardown
    FileUtils.remove_entry(@root) if @root
    super
  end

  def run_child(body, seconds: 5)
    @capture.run(command: [RbConfig.ruby, '-rjson', '-e', body], cwd: @root,
                 directory: @directory, seconds:, clock_id: 'test-controller')
  end

  def native_stream
    [
      { type: 'thread.started', thread_id: 'native-thread' },
      { type: 'turn.started' },
      { type: 'item.completed', item: { id: 'answer', type: 'agent_message', text: '日本語 🌊' } },
      { type: 'turn.completed', usage: { input_tokens: 12, output_tokens: 5 } }
    ].map { "#{JSON.generate(it)}\n" }.join
  end

  def write_stream
    "STDOUT.write(#{native_stream.dump}); STDOUT.flush;"
  end

  def private_log(name) = File.join(@directory, name)

  def refute_process(pid)
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
  end
end
