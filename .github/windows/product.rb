# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative 'session'

# Product paths that start other programs, run the way a PowerShell or cmd user starts Shaka:
# Ruby itself, with no Git Bash in between.
class WindowsProduct < WindowsSession
  EVIDENCE_RUN = %w[evidence run --repository shakacode/shaka --command test].freeze
  TEST = %w[-- test/executable_file_test.rb].freeze

  def call
    record('helper and command start tests') do
      ruby_tests('test/windows_helper_start_test.rb', 'test/windows_command_start_test.rb')
    end
    record('evidence run starts a repository command') { evidence_run }
    record('bin/install installs and verifies the helper') { install }
    self
  end

  private

  def evidence_run
    head = git_output('rev-parse', 'HEAD')
    output, error, success = capture([*helper, *EVIDENCE_RUN, '--root', root, '--ref', head, *TEST], 600)
    puts "  helper #{success ? 'succeeded' : 'failed'}: #{excerpt(error)}"
    return if completed?(output)

    raise "evidence run did not complete the test command: #{excerpt(output)}"
  end

  # The result JSON follows the command output on standard output.
  def completed?(output)
    result = JSON.parse(output[output.index('{')..])
    puts "  status #{result['status']} exit_code #{result['exit_code']}"
    result['status'] == 'completed' && result['exit_code'].to_i.zero?
  end

  def install
    Dir.mktmpdir('shaka-windows-install') do |home|
      environment = { 'HOME' => home, 'USERPROFILE' => home }
      output, status = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), '--agent', 'codex')
      puts "  exit #{status.exitstatus}: #{excerpt(output)}"
      raise 'bin/install failed' unless status.success?
    end
  end

  def helper
    scripts = File.join(root, 'skills/shaka/scripts')
    [RbConfig.ruby, '--disable-gems', '--disable-rubyopt', '-r', File.join(scripts, '../lib/shaka/ruby_requirement.rb'),
     File.join(scripts, 'shaka.rb')]
  end

  def git_output(*arguments)
    output, status = Open3.capture2('git', '-C', root, *arguments)
    raise "git #{arguments.first} failed" unless status.success?

    output.strip
  end
end
