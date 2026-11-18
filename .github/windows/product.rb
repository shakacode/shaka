# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative 'session'

# Product paths that start other programs, run the way a PowerShell or cmd user starts Shaka:
# Ruby itself, with no Git Bash in between and none of Git's or MSYS2's Unix tools on PATH.
class WindowsProduct < WindowsSession
  EVIDENCE_RUN = %w[evidence run --repository shakacode/shaka --command test].freeze
  TEST = %w[-- test/executable_file_test.rb].freeze
  CANDIDATE = 'shaka-windows-candidate'
  UNIX_TOOLS = %r{msys64|[\\/]Git[\\/](?:usr[\\/]bin|bin|mingw64[\\/]bin)[\\/]?\z}i

  def call
    record('helper and command start tests') do
      ruby_tests('test/windows_helper_start_test.rb', 'test/windows_command_start_test.rb',
                 'test/windows_local_review_test.rb')
    end
    record('evidence run starts a repository command') { evidence_run }
    record('review run reads the change and looks for the reviewer') { review_run }
    record('bin/install installs and verifies the helper') { install }
    self
  end

  private

  def evidence_run
    head = git_output('rev-parse', 'HEAD')
    output, error, success = capture([native_path, *helper, *EVIDENCE_RUN, '--root', root, '--ref', head, *TEST], 600)
    puts "  helper #{success ? 'succeeded' : 'failed'}: #{excerpt(error)}"
    return if completed?(output)

    raise "evidence run did not complete the test command: #{excerpt(output)}"
  end

  # No reviewer CLI is installed here, so a run that read the change through Git ends at the lookup.
  def review_run
    head = git_output('rev-parse', 'HEAD')
    output, error, = capture([native_path, *helper, 'review', 'run', '--root', root, '--head', head, '--base', head,
                              '--reviewer', 'anthropic/claude', '--timeout-seconds', '60'], 300)
    result = JSON.parse(output[(output.index('{') || 0)..])
    puts "  #{result['failure_stage']}: #{result['reason']}"
    return if result['failure_stage'] == 'executable_missing'

    raise "review run stopped before the reviewer lookup: #{excerpt(error)}"
  end

  # The result JSON follows the command output on standard output.
  def completed?(output)
    result = JSON.parse(output[(output.index('{') || 0)..])
    puts "  status #{result['status']} exit_code #{result['exit_code']}"
    result['status'] == 'completed' && result['exit_code'].to_i.zero?
  end

  # Installs this checkout's head, not upstream main, from a local branch the installer clones.
  def install
    head = git_output('rev-parse', '--short', 'HEAD')
    git_output('branch', '--force', CANDIDATE, 'HEAD')
    output, status = Dir.mktmpdir('shaka-windows-install') { |home| run_install(home) }
    puts "  exit #{status.exitstatus}: #{excerpt(output)}"
    raise "bin/install did not verify candidate #{head}" unless status.success? && output.include?("(#{head})")
  ensure
    git_output('branch', '--delete', '--force', CANDIDATE)
  end

  def run_install(home)
    Open3.capture2e(native_path.merge('HOME' => home, 'USERPROFILE' => home), RbConfig.ruby,
                    File.join(root, 'bin/install'), '--agent', 'codex', '--repository', root, '--branch', CANDIDATE)
  end

  # A native shell finds git through Git\cmd and nothing from Git's Unix tree.
  def native_path
    entries = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).grep_v(UNIX_TOOLS)
    puts "  PATH keeps #{entries.size} entries without Unix tools"
    { 'PATH' => entries.join(File::PATH_SEPARATOR) }
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
