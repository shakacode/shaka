# frozen_string_literal: true

require 'json'
require_relative 'product_install'
require_relative 'session'

# Product paths that start other programs, run the way a PowerShell or cmd user starts Shaka:
# Ruby itself, with no Git Bash in between and none of Git's or MSYS2's Unix tools on PATH.
class WindowsProduct < WindowsSession
  include WindowsProductInstall

  START_TESTS = %w[test/windows_helper_start_test.rb test/windows_command_start_test.rb
                   test/evidence_windows_check_test.rb].freeze
  EVIDENCE_RUN = %w[evidence run --repository shakacode/shaka --command test].freeze
  TEST = %w[-- test/executable_file_test.rb].freeze
  REVIEW_TESTS = %w[test/windows_local_review_test.rb test/windows_review_lookup_test.rb
                    test/doctor_windows_stop_test.rb].freeze
  # Not bash.exe: System32 ships one as the WSL launcher.
  UNIX_TOOL_NAMES = %w[sh.exe env.exe dirname.exe].freeze
  UNIX_TOOLS = %r{msys64|[\\/]Git[\\/](?:usr[\\/]bin|bin|mingw64[\\/]bin)[\\/]?\z}i

  def call
    # One record per file, so a failing file does not hide the others' counts.
    (START_TESTS + REVIEW_TESTS).each { |file| record("start test #{File.basename(file)}") { start_test(file) } }
    record('evidence run starts a repository command') { evidence_run }
    record('review run reads the change and looks for the reviewer') { review_run }
    INSTALLS.each { |name, scenario| record(name) { install { |home, branch| send(scenario, home, branch) } } }
    self
  end

  private

  # A missing file fails its record instead of passing with fewer tests.
  def start_test(file)
    raise "missing test file: #{file}" unless File.file?(File.join(root, file))

    ruby_tests(file)
  end

  def evidence_run
    head = git_output('rev-parse', 'HEAD')
    output, error, success = capture([native_path, *helper, *EVIDENCE_RUN, '--root', root, '--ref', head, *TEST], 600)
    puts "  helper #{success ? 'succeeded' : 'failed'}: #{excerpt(error)}"
    return if success && completed?(output)

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

  # The start tests run with the same PATH as the product calls, so they also prove the native start.
  def test_env = super.merge(native_path)

  # A native shell finds git through Git\cmd and nothing from Git's Unix tree.
  # Refuses a filtered PATH that still reaches a Unix tool, which would undo the native premise.
  def native_path
    entries = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).grep_v(UNIX_TOOLS)
    tools = entries.product(UNIX_TOOL_NAMES).map { |entry, tool| File.join(entry, tool) }.select { File.file?(it) }
    raise "filtered PATH still reaches #{tools.join(', ')}" unless tools.empty?

    puts "  PATH keeps #{entries.size} entries without Unix tools"
    { 'PATH' => entries.join(File::PATH_SEPARATOR) }
  end

  def helper
    scripts = File.join(root, 'skills/shaka/scripts')
    [RbConfig.ruby, '--disable-gems', '--disable-rubyopt', '-r', File.join(scripts, '../lib/shaka/ruby_requirement.rb'),
     File.join(scripts, 'shaka.rb')]
  end

  # An inherited GIT_DIR or similar would point git at another repository, as Source#git_raw notes.
  def git_environment = ENV.keys.grep(/\AGIT_/).to_h { |key| [key, nil] }

  def git_output(*arguments)
    output, status = Open3.capture2(git_environment, 'git', '-C', root, *arguments)
    raise "git #{arguments.first} failed" unless status.success?

    output.strip
  end
end
