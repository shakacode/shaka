# frozen_string_literal: true

require_relative 'session'

# Loading and running the shebang scripts under .agents/shaka/bin.
class WindowsCommands < WindowsSession
  TEST = 'test/cursor_stop_hook_test.rb'

  def call
    record('repository commands load') { load_commands }
    record('repository test command runs') { run_test_command }
    record('repository command tests') { ruby_tests('test/executable_file_test.rb', 'test/repository_config_test.rb') }
    self
  end

  private

  def load_commands
    require_subject 'shaka/repository_config'
    config = Shaka::RepositoryConfig.load(root:)
    names = config.commands.keys
    raise 'no commands loaded' if names.empty?

    names.each { |name| assert_command_file(config.command(name)) }
    puts "  loaded #{names.join(', ')}"
  end

  def assert_command_file(relative)
    path = File.join(root, relative)
    raise "#{relative} is not a file" unless File.file?(path)
  end

  def run_test_command
    script = File.join(root, '.agents/shaka/bin/test')
    puts "  direct spawn: #{direct_spawn(script)}"
    result = bash_spawn(script)
    puts "  git bash: #{result}"
    return if result == 'exit 0'

    raise 'Git bash did not finish .agents/shaka/bin/test successfully'
  end

  def direct_spawn(script)
    _output, status = Open3.capture2e(script, TEST, chdir: root)
    "exit #{status.exitstatus}"
  rescue SystemCallError => e
    "#{e.class}: #{e.message}"
  end

  def bash_spawn(script)
    output, status = Open3.capture2e(git_bash, script, TEST, chdir: root)
    puts output
    "exit #{status.exitstatus}"
  end
end
