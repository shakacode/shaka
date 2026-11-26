# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'tmpdir'
require_relative 'session'

# Product paths that start other programs, run the way a PowerShell or cmd user starts Shaka:
# Ruby itself, with no Git Bash in between and none of Git's or MSYS2's Unix tools on PATH.
class WindowsProduct < WindowsSession
  START_TESTS = %w[test/windows_helper_start_test.rb test/windows_command_start_test.rb
                   test/evidence_windows_check_test.rb].freeze
  EVIDENCE_RUN = %w[evidence run --repository shakacode/shaka --command test].freeze
  TEST = %w[-- test/executable_file_test.rb].freeze
  # Not bash.exe: System32 ships one as the WSL launcher.
  UNIX_TOOL_NAMES = %w[sh.exe env.exe dirname.exe].freeze
  UNIX_TOOLS = %r{msys64|[\\/]Git[\\/](?:usr[\\/]bin|bin|mingw64[\\/]bin)[\\/]?\z}i

  def call
    # One record per file, so a failing file does not hide the others' counts.
    START_TESTS.each { |file| record("start test #{File.basename(file)}") { start_test(file) } }
    record('evidence run starts a repository command') { evidence_run }
    record('bin/install installs and verifies the helper') { install }
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

  # The result JSON follows the command output on standard output.
  def completed?(output)
    result = JSON.parse(output[(output.index('{') || 0)..])
    puts "  status #{result['status']} exit_code #{result['exit_code']}"
    result['status'] == 'completed' && result['exit_code'].to_i.zero?
  end

  # Installs this checkout's head, not upstream main, from a local branch the installer clones.
  # The branch name is new for each run, and only a branch this run created is deleted.
  def install
    head = git_output('rev-parse', 'HEAD')
    branch = "shaka-windows-candidate-#{SecureRandom.hex(6)}"
    git_output('branch', branch, 'HEAD')
    created = branch
    check_install(head, *Dir.mktmpdir('shaka-windows-install') { |home| install_and_verify(home, branch) })
  ensure
    delete_branch(created) if created
  end

  # Cleanup reports a failed delete instead of hiding the install's own error.
  def delete_branch(branch)
    git_output('branch', '--delete', '--force', branch)
  rescue RuntimeError => e
    puts "  cleanup: #{e.message}"
  end

  # The installer prints the revision it verified, abbreviated to however many digits Git chooses.
  def verified?(output, head)
    output[/^Verified Shaka installation: .* \((\h{7,40})\)\r?$/, 1].then { |shown| shown && head.start_with?(shown) }
  end

  # The second run reads the record the first one saved, as a later --verify or --update does.
  def install_and_verify(home, branch)
    installed, installed_ok = run_installer(home, '--agent', 'codex', '--repository', root, '--branch', branch)
    checked, checked_ok = run_installer(home, '--verify')
    puts "  --verify #{checked_ok ? 'succeeded' : 'failed'}: #{excerpt(checked)}"
    [installed, installed_ok && checked_ok, saved_source(home)]
  end

  def check_install(head, output, success, source)
    puts "  #{success ? 'succeeded' : 'failed'}: #{excerpt(output)}"
    puts "  saved identity: #{source.inspect}"
    raise "bin/install did not verify candidate #{head}" unless success && verified?(output, head)
    return if source == { 'kind' => 'revision', 'revision' => head }

    raise "bin/install did not save the exact revision #{head}"
  end

  # The record's source identity says whether the install counted as the exact revision.
  def saved_source(home)
    record = File.join(home, '.local/share/shaka/source/.git/shaka-install.json')
    File.file?(record) ? JSON.parse(File.read(record)).dig('identity', 'source')&.slice('kind', 'revision') : nil
  end

  # Bounded, so a hung install fails the record instead of holding the job.
  def run_installer(home, *arguments)
    environment = native_path.merge('HOME' => home, 'USERPROFILE' => home)
    output, error, success = capture([environment, RbConfig.ruby, File.join(root, 'bin/install'), *arguments], 600)
    ["#{output}#{error}", success]
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
  def git_output(*arguments)
    environment = ENV.keys.grep(/\AGIT_/).to_h { |key| [key, nil] }
    output, status = Open3.capture2(environment, 'git', '-C', root, *arguments)
    raise "git #{arguments.first} failed" unless status.success?

    output.strip
  end
end
