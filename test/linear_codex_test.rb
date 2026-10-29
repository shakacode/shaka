# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shellwords'
load File.expand_path('../examples/linear-codex', __dir__)

class LinearCodexTest < Minitest::Test
  def setup
    skip 'The optional adapter targets macOS shells' if WINDOWS
    @directory = Dir.mktmpdir('linear-codex-')
    @environment = {
      'LINEAR_WORK_DIR' => @directory,
      'LINEAR_PROMPT' => "Fix the selected issue\nKeep its existing behavior",
      'LINEAR_ISSUE_IDENTIFIER' => 'ENG-123',
      'LINEAR_ISSUE_BRANCH_NAME' => 'engineer/eng-123-fix'
    }
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_hands_the_selected_repository_and_complete_context_to_shaka_work
    arguments = Shellwords.split(LinearCodex.command(@environment))
    assert_equal %w[work --host codex --repo], arguments[1..4]
    assert_equal [@directory, '--'], arguments[5..6]
    context = JSON.parse(arguments.last.lines.last)
    assert_equal @environment.values_at('LINEAR_PROMPT', 'LINEAR_ISSUE_IDENTIFIER', 'LINEAR_ISSUE_BRANCH_NAME'),
                 context.values_at('prompt', 'issue', 'branch')
    assert File.executable?(arguments.first)
  end

  def test_shell_metacharacters_and_multiline_content_stay_literal_through_the_terminal_shell
    marker = File.join(@directory, 'injected')
    repository = File.join(@directory, "repo ' $(touch #{marker})")
    FileUtils.mkdir_p(repository)
    @environment.merge!('LINEAR_WORK_DIR' => repository,
                        'LINEAR_PROMPT' => "quotes '\"; $(touch #{marker})\n`touch #{marker}`",
                        'LINEAR_ISSUE_BRANCH_NAME' => "branch; touch #{marker}")
    arguments = shell_handoff
    assert_equal repository, arguments[4]
    assert_equal @environment['LINEAR_PROMPT'], JSON.parse(arguments.last.lines.last)['prompt']
    refute_path_exists marker
  end

  def test_rejects_incomplete_context_before_opening_terminal
    @environment.each_key do |key|
      environment = @environment.merge(key => ' ')
      error = assert_raises(ArgumentError) { LinearCodex.command(environment) }
      assert_includes error.message, key
    end
  end

  def test_rejects_missing_or_relative_repository_and_missing_helper
    ['relative', File.join(@directory, 'missing')].each do |path|
      assert_raises(ArgumentError) { LinearCodex.command(@environment.merge('LINEAR_WORK_DIR' => path)) }
    end
    assert_raises(ArgumentError) { LinearCodex.command(@environment, helper: File.join(@directory, 'missing')) }
  end

  def test_rejects_nul_before_a_shell_or_applescript_receives_it
    assert_raises(ArgumentError) { LinearCodex.command(@environment.merge('LINEAR_PROMPT' => "bad\0prompt")) }
  end

  def test_reports_terminal_failure
    _output, error = capture_io { assert_equal 1, LinearCodex.run(@environment, runner: ->(*) { false }) }
    assert_includes error, 'Terminal could not be opened'
  end

  def test_passes_the_shell_command_as_an_applescript_argument
    invocation = nil
    runner = lambda do |*arguments|
      invocation = arguments
      true
    end
    assert_equal 0, LinearCodex.run(@environment, runner: runner)
    assert_equal ['/usr/bin/osascript', '-e', LinearCodex::APPLESCRIPT], invocation[0..2]
    assert_equal LinearCodex.command(@environment), invocation.last
  end

  private

  def shell_handoff
    helper = File.join(@directory, "helper ' script")
    capture = File.join(@directory, 'capture.json')
    File.write(helper, "#!/usr/bin/env ruby\nrequire 'json'\nFile.write(ENV.fetch('CAPTURE'), JSON.generate(ARGV))\n")
    FileUtils.chmod(0o755, helper)
    command = LinearCodex.command(@environment, helper: helper)
    _output, error, status = Open3.capture3({ 'CAPTURE' => capture }, '/bin/sh', '-c', command)
    assert_predicate status, :success?, error
    JSON.parse(File.read(capture))
  end
end
