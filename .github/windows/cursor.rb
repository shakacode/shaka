# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'
require_relative 'session'

# Cursor stop-hook payload, the .cmd launcher, and doctor's install check.
class WindowsCursor < WindowsSession
  SESSION = '11111111-1111-4111-8111-111111111111'
  GENERATION = '00000000-0000-4000-8000-000000000002'

  def call
    record('hook keeps a UTF-8 BOM payload') { bom_payload }
    record('cursor-usage-hook.cmd records usage') { cmd_launcher }
    record('doctor recognizes the Windows launcher') { recognize_launcher }
    record('cursor hook tests') { ruby_tests('test/cursor_stop_hook_test.rb', 'test/cursor_usage_test.rb') }
    self
  end

  private

  def bom_payload
    hook = File.join(root, 'skills/shaka/scripts/cursor-usage-hook')
    record_payload([RbConfig.ruby, '--disable-gems', hook], bom_bytes, nil)
  end

  def cmd_launcher
    cmd = File.join(root, 'skills/shaka/scripts/cursor-usage-hook.cmd')
    raise "launcher missing: #{cmd}" unless File.file?(cmd)

    Dir.mktmpdir { |dir| launch_cmd(cmd, dir) }
  end

  def launch_cmd(cmd, dir)
    usage = File.join(dir, 'usage')
    FileUtils.mkdir_p(usage)
    record_payload(['cmd.exe', '/d', '/c', cmd.tr('/', '\\')], bom_bytes, usage)
  end

  def recognize_launcher
    require_subject 'shaka/doctor/cursor_stop_hook'
    cmd = 'skills/shaka/scripts/cursor-usage-hook.cmd'
    quoted = '"C:\\Ruby34-x64\\bin\\ruby.exe" "skills\\shaka\\scripts\\cursor-usage-hook"'
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'hooks.json')
      expect_installed(path, cmd, 'doctor ignores cursor-usage-hook.cmd')
      expect_installed(path, quoted, 'doctor ignores a quoted ruby.exe command')
      expect_absent(path)
    end
  end

  def expect_installed(path, command, message)
    write_hook(path, command)
    raise message unless Shaka::Doctor::CursorStopHook.installed?(path)
  end

  def expect_absent(path)
    write_hook(path, 'echo cursor-usage-hook')
    raise 'doctor accepts echo cursor-usage-hook' if Shaka::Doctor::CursorStopHook.installed?(path)
  end

  def record_payload(command, raw, usage)
    Dir.mktmpdir do |dir|
      saved, detail = invoke_hook(command, raw, usage || dir)
      next if saved && saved['generation_id'] == GENERATION && saved['input_tokens'] == 100

      raise "record=#{saved.inspect} #{detail}"
    end
  end

  def invoke_hook(command, raw, directory)
    _out, err, status = Open3.capture3({ 'CURSOR_USAGE_DIR' => directory }, *command, **hook_options(raw))
    [read_record(directory), "exit #{status.exitstatus}: #{excerpt(err)}"]
  end

  def hook_options(raw)
    options = { chdir: root }
    return options unless raw

    options.merge(stdin_data: raw, binmode: true)
  end

  def read_record(directory)
    file = File.join(directory, "#{SESSION}.jsonl")
    return unless File.file?(file)

    JSON.parse(File.read(file).lines.first)
  end

  def write_hook(path, command)
    body = { 'hooks' => { 'stop' => [{ 'command' => command }] } }
    File.write(path, JSON.generate(body))
  end

  def bom_bytes = "\xEF\xBB\xBF".b + hook_payload.b

  def hook_payload
    JSON.generate(
      'conversation_id' => SESSION, 'generation_id' => GENERATION, 'hook_event_name' => 'stop',
      'input_tokens' => 100, 'output_tokens' => 20, 'model' => 'cursor-grok-4.6-medium'
    )
  end
end
