# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'yaml'
require 'fileutils'
require 'shaka/canary/run'

class CanaryWorkflowTest < Minitest::Test
  def setup
    @workflow = YAML.load_file(File.expand_path('../.github/workflows/canary.yml', __dir__))
    @text = File.read(File.expand_path('../.github/workflows/canary.yml', __dir__))
  end

  def test_push_to_main_and_manual_dispatch_share_one_cancellable_group
    on = @workflow['on'] || @workflow[true]

    assert_equal ['main'], on.dig('push', 'branches')
    assert_includes on.keys, 'workflow_dispatch'
    assert_equal 'shaka-canary', @workflow.dig('concurrency', 'group')
    assert @workflow.dig('concurrency', 'cancel-in-progress')
  end

  def test_unconfigured_runs_skip_and_the_job_cannot_write_with_the_default_token
    permissions = @workflow.fetch('permissions')

    assert_equal 'read', permissions['contents']
    assert_equal 'read', permissions['actions']
    refute_includes permissions.values, 'write'
    assert_includes @text, 'vars.SHAKA_CANARY_REPO'
    assert_includes @text, 'secrets.SHAKA_CANARY_MODEL_KEY'
    assert_includes @text, 'secrets.SHAKA_CANARY_TOKEN'
    assert_includes @text, 'ruby bin/canary preflight'
    assert_includes @text, "steps.preflight.outputs.action == 'skip'"
    refute_includes @text, 'missing stats line'
  end

  def test_the_agent_step_uses_the_cursor_key_only_there
    step = @workflow.dig('jobs', 'canary', 'steps').find { |item| item['name'] == 'Run the fixed task headless' }

    assert_equal '${{ secrets.SHAKA_CANARY_MODEL_KEY }}', step.dig('env', 'CURSOR_API_KEY')
    assert_includes step['run'], 'agent -p --force --trust'
    assert_includes @text, 'bin/install'
    assert_includes @text, 'checkout --detach "$GITHUB_SHA"'
  end
end

CANARY_BODY = <<~BODY
  ## Summary

  Add farewell.

  ## Intent

  The canary repeats one task.

  ## Verification

  Ran the greeting test.

  ## Shaka metrics

  AI spend $1.00 · Prompt to CI 5m · CI to ready 9m (1 round) · Ready to merged pending

  | Check | Result |
  | --- | --- |
  | body | pass |

  See [the run](https://github.com/shakacode/shaka/commit/abc).
BODY

class CanaryCollectTest < Minitest::Test
  def test_collect_checks_the_new_pull_request_and_publish_closes_the_older_one
    Dir.mktmpdir { |dir| assert_published(*collected(dir)) }
  end

  def test_collect_fails_closed_when_no_pull_request_opened
    Dir.mktmpdir do |dir|
      runner = FakeCanary.new('[]')
      result = Shaka::Canary::Collect.call(environment(dir), runner: runner)

      assert_false result['ok']
      assert_nil result['number']
      assert_includes result['summary'], 'no canary pull request'
    end
  end

  def collected(dir)
    env = environment(dir)
    File.write(File.join(dir, 'canary-started-at'), "2026-10-26T12:00:00Z\n")
    runner = FakeCanary.new(list_body)
    [dir, env, runner, Shaka::Canary::Collect.call(env, runner: runner)]
  end

  def assert_published(dir, env, runner, result)
    assert_true result['ok'], result['summary']
    assert_equal 2, result['number']
    assert_includes File.read(File.join(dir, 'canary-summary.md')), 'Canary passed'
    assert_equal 0, Shaka::Canary::Publish.call(env, runner: runner)
    assert_equal %w[gh pr comment 2], command_prefix(runner, 'comment')
    assert_equal %w[gh pr close 1], command_prefix(runner, 'close')
  end

  def command_prefix(runner, name)
    runner.commands.find { |argv| argv[2] == name }.first(4)
  end

  def environment(dir)
    { 'RUNNER_TEMP' => dir, 'SHAKA_CANARY_REPO' => 'shakacode/shaka-canary', 'SHAKA_CANARY_KEEP' => '1',
      'CANARY_DIR' => dir, 'SHAKA_HELPER' => 'shaka', 'GITHUB_SHA' => 'abc123',
      'GITHUB_REPOSITORY' => 'shakacode/shaka', 'GITHUB_SERVER_URL' => 'https://github.com',
      'GITHUB_RUN_ID' => '99', 'GITHUB_WORKSPACE' => dir }
  end

  def list_body
    previous = CANARY_BODY.sub('$1.00', '$0.40')
    pulls = [pull(2, CANARY_BODY, '2026-10-26T12:30:00Z'), pull(1, previous, '2026-10-26T11:00:00Z')]
    JSON.generate(pulls)
  end

  def pull(number, body, created)
    { 'number' => number, 'state' => 'OPEN', 'createdAt' => created, 'body' => body,
      'url' => "https://example/#{number}" }
  end
end

class FakeCanary
  attr_reader :commands

  def initialize(list)
    @list = list
    @commands = []
  end

  def capture(argv, chdir: nil)
    @commands << argv
    @dir = chdir
    return { 'out' => @list, 'err' => '', 'ok' => true } if argv[0] == 'gh' && argv[2] == 'list'
    return { 'out' => 'deadbeef', 'err' => '', 'ok' => true } if argv.include?('rev-parse')
    return { 'out' => "abc123 Add canary\n", 'err' => '', 'ok' => true } if argv.include?('log')
    return { 'out' => '[]', 'err' => '', 'ok' => true } if argv[1] == 'api'

    { 'out' => "ok\n", 'err' => '', 'ok' => true }
  end
end

class CanaryTemplateTest < Minitest::Test
  def test_the_template_validate_script_passes_and_the_seam_loads
    Dir.mktmpdir { |dir| assert_template(copy_template(dir)) }
  end

  def copy_template(dir)
    root = File.expand_path('../templates/shaka-canary', __dir__)
    FileUtils.cp_r(Dir.children(root).map { |name| File.join(root, name) }, dir)
    FileUtils.chmod('+x', Dir.glob(File.join(dir, '.agents/shaka/bin/*')))
    dir
  end

  def assert_template(dir)
    _out, status = Open3.capture2(RbConfig.ruby, File.join(dir, 'test/greeting_test.rb'))
    assert_equal 0, status.exitstatus
    commit_template(dir)
    out, check = Open3.capture2(*SHAKA_COMMAND, 'seam', 'check', '--root', dir, '--local')
    assert_equal 0, check.exitstatus, out
    assert_includes out, '"required": "none"'
  end

  def commit_template(dir)
    [nil, %w[add .], %w[-c user.email=canary@example.com -c user.name=Canary commit -qm template]].each do |args|
      next system(TEST_GIT, '-C', dir, 'init', '-b', 'main', '-q') unless args

      assert system(TEST_GIT, '-C', dir, *args), args.join(' ')
    end
  end
end
