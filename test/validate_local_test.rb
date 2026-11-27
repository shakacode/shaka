# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'open3'
require 'tmpdir'

# Stand-ins for the tools validate-local calls; each logging stub records its arguments.
module ValidateLocalStubs
  LOGGING_STUB = <<~SH
    #!/bin/sh
    printf '%s %s\n' "$(basename "$0")" "$*" >> "$STUB_LOG"
    [ "$(basename "$0")" != "${STUB_FAIL:-}" ] || exit 1
  SH

  # The tools validate-local calls. `bundle exec` runs the named tool, except that RuboCop only logs.
  # Some hosts ignore TMPDIR, so mktemp names the directory where cleanup is checked.
  STUBS = %w[.agents/shaka/bin/validate bin/check-docs-navigation bin/run-tests bin/lefthook/ruby-check]
          .to_h { [it, LOGGING_STUB] }.merge(
            'stubs/bundle' => <<~SH,
              #!/bin/sh
              shift
              if [ "$1" = rubocop ]; then shift; printf 'rubocop %s\n' "$*" >> "$STUB_LOG"; exit 0; fi
              [ "$1" = ruby ] && shift
              exec "$@"
            SH
            'stubs/ruby' => "#!/bin/sh\nexec \"$@\"\n",
            'stubs/mktemp' => "#!/bin/sh\nexec /usr/bin/mktemp \"$@\" \"$STUB_TMP/tmp.XXXXXX\"\n"
          ).freeze
end

# Runs .agents/shaka/bin/validate-local in a scratch repository whose tools are stubs that log
# their arguments, so each test sees which checks the script chose and what they received.
class ValidateLocalTest < Minitest::Test
  SCRIPT = '.agents/shaka/bin/validate-local'
  include ValidateLocalStubs

  def setup
    @root = Dir.mktmpdir('validate-local')
    @tmp = Dir.mktmpdir('validate-local-tmp')
    git('init', '-q')
    install_scripts
    File.write(File.join(@root, 'lib/example.rb'), "x = 1\n")
    File.write(File.join(@root, 'docs/guide.md'), "# Guide\n")
    File.write(File.join(@root, '.rubocop.yml'), "AllCops: {}\n")
    commit('Initial')
    @base = git('rev-parse', 'HEAD').strip
  end

  def teardown
    FileUtils.rm_rf([@root, @tmp])
  end

  def test_a_ruby_change_runs_the_reachable_tests_and_lints_the_changed_files
    File.write(File.join(@root, 'lib/example.rb'), "x = 2\n")
    File.write(File.join(@root, 'lib/added.rb'), "y = 1\n")
    git('rm', '-q', 'docs/guide.md')
    File.write(File.join(@root, 'bin/docs-only-change'), "#!/bin/sh\nexit 0\n") # Ignored: the base copy decides.
    commit('Change Ruby')

    _output, status = validate_local

    assert_predicate status, :success?
    assert_includes log, "run-tests --changed #{@base}"
    assert_includes log, 'ruby-check lint bin/docs-only-change docs/guide.md lib/added.rb lib/example.rb'
    refute_includes log, 'rubocop'
  end

  def test_a_documentation_change_hands_off_to_validate_and_cleans_up
    File.write(File.join(@root, 'docs/guide.md'), "# Guide\n\nMore.\n")
    commit('Change docs')

    assert_predicate validate_local.last, :success?
    assert_equal "validate \n", log
    assert_empty Dir.children(@tmp)
  end

  def test_whitespace_fails_before_a_documentation_handoff
    File.write(File.join(@root, 'lib/example.rb'), "x = 2  \n")
    File.write(File.join(@root, 'bin/docs-only-change'), "#!/bin/sh\nexit 0\n")
    commit('Misclassified change')

    output, status = validate_local

    refute_predicate status, :success?
    assert_includes output, 'trailing whitespace'
    assert_empty log
  end

  def test_untracked_whitespace_fails_and_empty_files_and_embedded_checkouts_do_not
    %w[lib/empty.rb --help].each { File.write(File.join(@root, it), '') }
    git('init', '-q', File.join(@root, 'lib/embedded'))
    assert_predicate validate_local.last, :success?

    File.write(File.join(@root, 'lib/new.rb'), "z = 1  \n")
    output, status = validate_local

    refute_predicate status, :success?
    assert_includes output, 'trailing whitespace'
  end

  def test_adding_nested_or_deleting_root_rubocop_settings_lints_every_file
    File.write(File.join(@root, 'lib/.rubocop.yml'), "AllCops: {}\n")
    commit('Add nested RuboCop settings')
    assert_full_lint

    git('rm', '-q', '.rubocop.yml', 'lib/.rubocop.yml')
    commit('Remove RuboCop settings')
    assert_full_lint
  end

  def test_a_failing_test_run_fails_before_lint
    File.write(File.join(@root, 'lib/example.rb'), "x = 2\n")
    commit('Change Ruby')

    _output, status = validate_local('STUB_FAIL' => 'run-tests')

    refute_predicate status, :success?
    refute_includes log, 'ruby-check'
  end

  private

  def install_scripts
    %w[.agents/shaka/bin bin/lefthook docs lib stubs].each { FileUtils.mkdir_p(File.join(@root, it)) }
    [SCRIPT, 'bin/docs-only-change'].each { FileUtils.cp(File.expand_path("../#{it}", __dir__), File.join(@root, it)) }
    File.write(File.join(@root, '.gitignore'), "stubs/\nstub.log\n")
    STUBS.each { |path, content| write_executable(path, content) }
  end

  def assert_full_lint
    assert_predicate validate_local.last, :success?
    assert_equal "rubocop \n", log.lines.last
  end

  def write_executable(path, content)
    File.write(File.join(@root, path), content)
    FileUtils.chmod(0o755, File.join(@root, path))
  end

  def validate_local(environment = {})
    File.write(stub_log, '')
    env = { 'BASH_ENV' => nil, 'SHAKA_BASE_REF' => @base, 'STUB_LOG' => stub_log, 'STUB_TMP' => @tmp,
            'PATH' => "#{File.join(@root, 'stubs')}:#{ENV.fetch('PATH')}" }
    Open3.capture2e(env.merge(environment), File.join(@root, SCRIPT), chdir: @root)
  end

  def stub_log = File.join(@root, 'stub.log')

  def log = File.read(stub_log)

  def commit(message)
    git('add', '-A')
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', message)
  end

  def git(*args)
    output, status = Open3.capture2e('git', '-C', @root, *args)
    raise "git #{args.first} failed: #{output}" unless status.success?

    output
  end
end
