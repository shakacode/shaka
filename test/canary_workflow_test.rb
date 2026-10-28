# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'yaml'
require 'fileutils'
require 'shaka/canary/run'
require_relative 'official_install_support'

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

  def test_preflight_checks_the_key_and_only_the_agent_step_receives_credentials
    step = @workflow.dig('jobs', 'canary', 'steps').find { |item| item['name'] == 'Run the fixed task headless' }
    preflight = @workflow.dig('jobs', 'canary', 'steps').find { |item| item['id'] == 'preflight' }

    assert_equal '${{ secrets.SHAKA_CANARY_MODEL_KEY }}', preflight.dig('env', 'SHAKA_CANARY_MODEL_KEY')
    assert_equal '${{ secrets.SHAKA_CANARY_MODEL_KEY }}', step.dig('env', 'CURSOR_API_KEY')
    assert_includes step['run'], 'agent -p --force --trust'
    assert_includes @text, 'bin/install'
    assert_includes @text, 'checkout -B main "$GITHUB_SHA"'
  end

  def test_the_remote_installer_has_no_step_credentials
    installer = @workflow.dig('jobs', 'canary', 'steps').find { |item| item['name'] == 'Install Cursor CLI' }
    assert_nil installer['env']
    assert_includes installer['run'], 'https://cursor.com/install'
  end

  def test_clone_and_prompt_use_the_repository_normalized_by_preflight
    steps = @workflow.dig('jobs', 'canary', 'steps')
    ['Clone the canary repository', 'Run the fixed task headless'].each do |name|
      step = steps.find { |item| item['name'] == name }
      assert_equal '${{ steps.preflight.outputs.repo }}', step.dig('env', 'SHAKA_CANARY_REPO')
      assert_includes step['run'], '"$SHAKA_CANARY_REPO"'
      refute_includes step['run'], 'vars.SHAKA_CANARY_REPO'
    end
  end

  def test_cancelled_runs_skip_collection_publication_and_finish
    steps = @workflow.dig('jobs', 'canary', 'steps').last(3)
    steps.each do |step|
      assert_equal "${{ !cancelled() && steps.preflight.outputs.action == 'run' }}", step['if']
    end
  end

  def test_the_controller_gets_the_branch_from_the_installed_claim_command
    step = @workflow.dig('jobs', 'canary', 'steps').find { |item| item['name'] == 'Clone the canary repository' }

    assert_includes step['run'], '"$SHAKA_HELPER" claim --description "$slug"'
    assert_includes step['run'], 'echo "CANARY_BRANCH=$branch"'
  end
end

class CanaryInstallTest < Minitest::Test
  include OfficialInstallSupport

  def test_workflow_checkout_installs_the_pinned_revision_on_the_tracked_branch
    pinned = git('-C', @root, 'rev-parse', 'HEAD').strip
    File.write(File.join(@source, 'SKILL.md'), 'newer main')
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
    pin_from_workflow(pinned)
    official_install
    assert_equal pinned, JSON.parse(File.read(File.join(@root, '.git/shaka-install.json')))['revision']
    assert_equal 'version one', File.read(File.join(@destination, 'SKILL.md'))
  end

  def pin_from_workflow(pinned)
    text = File.read(File.expand_path('../.github/workflows/canary.yml', __dir__))
    line = text.lines.find { |item| item.include?('git -C "$dest" checkout') }
    out, status = Open3.capture2e({ 'dest' => @root, 'GITHUB_SHA' => pinned }, 'bash', '-c', line)
    assert_predicate status, :success?, out
  end

  def test_real_git_coverage_includes_the_first_cancelled_agent_revision
    first = fixture_revision('first attempt')
    current = fixture_revision('next attempt')
    Dir.mktmpdir do |dir|
      history = [{ 'headSha' => first, 'agent_started_at' => '2026-10-26T10:00:00Z' }]
      File.write(File.join(dir, 'canary-runs.json'), JSON.generate(history))
      env = { 'RUNNER_TEMP' => dir, 'GITHUB_WORKSPACE' => @root, 'GITHUB_SHA' => current }
      lines = Shaka::Canary::Coverage.new(env, Shaka::Canary::Runner.new).commits
      assert_named_revisions(lines, first, current)
    end
  end

  def assert_named_revisions(lines, *revisions)
    revisions.each { |revision| assert(lines.any? { |line| line.start_with?(revision[0, 7]) }) }
  end

  def fixture_revision(text)
    File.write(File.join(@source, 'SKILL.md'), text)
    commit_source
    git('-C', @root, 'rev-parse', 'HEAD').strip
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

  🤖 Codex · OpenAI · gpt-test · low - AI spend: $1.00 · ready in 14m

  **This head:** Prompt to CI 5m · CI to ready 9m · Ready to merged pending

  | Check | Result |
  | --- | --- |
  | body | pass |

  See [the run](https://github.com/shakacode/shaka/commit/abc).
BODY

module CanaryCollectionFixtures
  def environment(dir)
    { 'RUNNER_TEMP' => dir, 'SHAKA_CANARY_REPO' => 'shakacode/shaka-canary', 'SHAKA_CANARY_KEEP' => '1',
      'CANARY_DIR' => dir, 'SHAKA_HELPER' => 'shaka', 'GITHUB_SHA' => 'abc123',
      'GITHUB_REPOSITORY' => 'shakacode/shaka', 'GITHUB_SERVER_URL' => 'https://github.com',
      'GITHUB_RUN_ID' => '99', 'GITHUB_WORKSPACE' => dir, 'CANARY_BRANCH' => 'shaka-canary/run-99-1' }
  end

  def list_body
    previous = CANARY_BODY.sub('$1.00', '$0.40')
    pulls = [pull(2, CANARY_BODY, '2026-10-26T12:30:00Z'), pull(1, previous, '2026-10-26T11:00:00Z')]
    JSON.generate(pulls)
  end

  def pull(number, body, created)
    { 'number' => number, 'state' => 'OPEN', 'createdAt' => created, 'body' => body,
      'url' => "https://example/#{number}", 'isCrossRepository' => false,
      'headRefName' => "shaka-canary/run-#{number == 2 ? 99 : 98}-1" }
  end
end

class CanaryRetentionTest < Minitest::Test
  include CanaryCollectionFixtures

  def test_unreadable_open_inventory_fails_without_cleanup
    Dir.mktmpdir do |dir|
      endpoint = 'repos/shakacode/shaka-canary/pulls?state=open&per_page=100'
      runner = FakeCanary.new(list_body, failure: endpoint)
      result = Shaka::Canary::Collect.call(environment(dir), runner: runner)
      assert_false result['ok']
      assert_includes result['summary'], 'cannot list open canary pull requests'
      assert_empty result['close']
    end
  end

  def test_retention_uses_all_open_pulls_beyond_the_comparison_window
    Dir.mktmpdir do |dir|
      runner = retention_runner
      File.write(File.join(dir, 'canary-started-at'), "2026-10-26T12:00:00Z\n")
      result = Shaka::Canary::Collect.call(environment(dir).merge('SHAKA_CANARY_KEEP' => '30'), runner: runner)
      assert_true result['ok'], result['summary']
      assert_equal 31, result['number']
      assert_equal [1], result['close']
    end
  end

  def retention_runner
    pulls = (1..31).map do |number|
      created = (Time.utc(2026, 10, 26, 12) + (number * 60)).iso8601
      branch = "shaka-canary/run-#{number == 31 ? 99 : number}-1"
      pull(number, CANARY_BODY, created).merge('headRefName' => branch)
    end.reverse
    FakeCanary.new(JSON.generate(pulls.first(30)), open_pulls: pulls)
  end
end

class CanaryCollectTest < Minitest::Test
  include CanaryCollectionFixtures

  def test_a_missing_trusted_base_never_falls_back_to_candidate_policy
    Dir.mktmpdir do |dir|
      runner, result = failed_collection(dir, 'rev-parse')
      assert_false result['ok']
      assert_includes result['summary'], 'cannot resolve trusted canary base'
      assert_no_repository_checks(runner, resolves_base: true)
    end
  end

  def test_a_newer_fork_or_another_run_cannot_supply_executable_checks
    Dir.mktmpdir do |dir|
      runner, result = rejected_collection(dir)
      assert_false result['ok']
      assert_nil result['number']
      assert_empty result['close']
      assert_no_repository_checks(runner)
      refute(runner.commands.any? { |argv| argv[2] == 'checkout' })
    end
  end

  def rejected_collection(dir)
    File.write(File.join(dir, 'canary-started-at'), "2026-10-26T12:00:00Z\n")
    fork = pull(3, CANARY_BODY, '2026-10-26T12:40:00Z').merge('isCrossRepository' => true,
                                                              'headRefName' => 'shaka-canary/run-99-1')
    other = pull(4, CANARY_BODY, '2026-10-26T12:41:00Z').merge('headRefName' => 'shaka-canary/run-100-1')
    runner = FakeCanary.new(JSON.generate([fork, other]))
    [runner, Shaka::Canary::Collect.call(environment(dir), runner: runner)]
  end

  def test_failed_checkout_never_checks_the_previous_clone
    Dir.mktmpdir do |dir|
      runner, result = failed_collection(dir, 'checkout')

      assert_false result['ok']
      Shaka::Canary::Report::COMMANDS.each { |name| assert_includes result['summary'], "missing command check #{name}" }
      assert_no_repository_checks(runner)
    end
  end

  def test_failed_listing_reports_the_error_and_never_checks_or_closes_pulls
    Dir.mktmpdir do |dir|
      runner, result = failed_collection(dir, 'list')

      assert_false result['ok']
      assert_includes result['summary'], 'gh pr list failed: permission denied'
      refute_includes result['summary'], 'no canary pull request opened after the run started'
      assert_no_publication(dir, runner, result)
    end
  end

  def failed_collection(dir, failure)
    File.write(File.join(dir, 'canary-started-at'), "2026-10-26T12:00:00Z\n")
    runner = FakeCanary.new(list_body, failure: failure)
    [runner, Shaka::Canary::Collect.call(environment(dir), runner: runner)]
  end

  def assert_no_repository_checks(runner, resolves_base: false)
    refute(runner.commands.any? { |argv| argv.first == 'shaka' || argv.first.end_with?('/validate') })
    refute(runner.commands.any? { |argv| argv.include?('rev-parse') }) unless resolves_base
  end

  def assert_no_publication(dir, runner, result)
    assert_nil result['number']
    assert_empty result['close']
    assert_fallback_links(result['summary'])
    assert_equal result, JSON.parse(File.read(File.join(dir, 'canary-result.json')))
    assert_equal 0, Shaka::Canary::Publish.call(environment(dir), runner: runner)
    assert_equal 1, runner.commands.size
  end

  def assert_fallback_links(summary)
    assert_includes summary, 'https://github.com/shakacode/shaka/commit/abc123'
    assert_includes summary, 'https://github.com/shakacode/shaka/actions/runs/99'
  end

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
end

class CanaryRunnerTest < Minitest::Test
  def test_commands_without_a_directory_run_in_the_current_directory
    result = Shaka::Canary::Runner.new.capture([RbConfig.ruby, '-e', 'puts Dir.pwd'])

    assert_true result['ok']
    assert_equal "#{Dir.pwd}\n", result['out']
    assert_empty result['err']
  end

  def test_an_explicit_directory_and_command_failure_are_preserved
    Dir.mktmpdir do |dir|
      result = Shaka::Canary::Runner.new.capture(
        [RbConfig.ruby, '-e', 'puts Dir.pwd; warn "failed"; exit 7'], chdir: dir
      )

      assert_false result['ok']
      assert_equal "#{File.realpath(dir)}\n", result['out']
      assert_equal "failed\n", result['err']
    end
  end
end

class CanaryAttemptHistoryTest < Minitest::Test
  def test_only_successfully_completed_collection_steps_supply_coverage_boundaries
    name = 'Check the canary pull request and write the summary'
    steps = [{ 'name' => name, 'conclusion' => 'success', 'completed_at' => '2026-10-26T10:00:00Z' },
             { 'name' => name, 'conclusion' => 'cancelled', 'completed_at' => '2026-10-26T11:00:00Z' }]
    assert_equal Time.iso8601('2026-10-26T10:00:00Z'),
                 Shaka::Canary::AttemptHistory.collection_time([{ 'steps' => steps }])
  end

  def test_the_throttle_cli_persists_the_history_used_by_collection
    Dir.mktmpdir do |dir|
      path = prepare_cli_history(dir)
      args = %w[throttle --event push --repository owner/repo --run 99]
      out, error, status = Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}" }, RbConfig.ruby,
                                          File.expand_path('../bin/canary', __dir__), *args, '--runs', path)
      assert_predicate status, :success?, error
      assert_equal "0\n", out
      assert_equal '2020-01-01T00:00:00Z', JSON.parse(File.read(path)).first['agent_started_at']
    end
  end

  def prepare_cli_history(dir)
    step = { 'name' => 'Run the fixed task headless', 'started_at' => '2020-01-01T00:00:00Z' }
    pages = JSON.generate([{ 'jobs' => [{ 'steps' => [step] }] }])
    File.write(File.join(dir, 'gh'), "#!/bin/sh\ncat <<'JSON'\n#{pages}\nJSON\n")
    File.chmod(0o755, File.join(dir, 'gh'))
    File.join(dir, 'runs.json').tap { |path| File.write(path, '[{"databaseId":99,"headSha":"abc123"}]') }
  end

  def test_job_steps_include_earlier_attempts_of_the_current_run
    runner = history_runner(true)
    history = Shaka::Canary::AttemptHistory.capture([], repository: 'owner/repo', current: '99', runner: runner)

    assert_equal '2026-10-26T11:30:00Z', history.first['agent_started_at']
    assert_equal [['gh', 'api', '--paginate', '--slurp',
                   'repos/owner/repo/actions/runs/99/jobs?filter=all&per_page=100']], runner.commands
  end

  def test_unreadable_attempt_history_fails_instead_of_starting_another_agent
    error = assert_raises(RuntimeError) do
      Shaka::Canary::AttemptHistory.capture([{ 'databaseId' => 98 }], repository: 'owner/repo',
                                                                      current: '99', runner: history_runner(false))
    end
    assert_includes error.message, 'cannot read canary attempts: denied'
  end

  def history_runner(success)
    step = { 'name' => 'Run the fixed task headless', 'conclusion' => 'failure',
             'started_at' => '2026-10-26T11:30:00Z' }
    pages = [{ 'jobs' => [{ 'steps' => [step] }] }, { 'jobs' => [{ 'steps' => [] }] }]
    FakeCanaryHistory.new('ok' => success, 'err' => 'denied', 'out' => JSON.generate(pages))
  end
end

class CanaryCoverageTest < Minitest::Test
  include CanaryCollectionFixtures

  def test_a_cancelled_wait_does_not_hide_untested_commits
    Dir.mktmpdir do |dir|
      history = [{ 'headSha' => 'bbb2222', 'agent_started_at' => nil, 'collected_at' => nil },
                 { 'headSha' => 'aaa1111', 'collected_at' => '2026-10-26T10:00:00Z' }]
      File.write(File.join(dir, 'canary-runs.json'), JSON.generate(history))
      runner = FakeCanary.new('[]')
      Shaka::Canary::Coverage.new(environment(dir), runner).commits
      assert_equal 'aaa1111..abc123', runner.commands.last.last
    end
  end

  def test_cancelled_agents_are_included_even_before_the_first_completed_collection
    Dir.mktmpdir do |dir|
      history = [{ 'headSha' => 'aaa1111', 'agent_started_at' => '2026-10-26T10:00:00Z', 'collected_at' => nil }]
      File.write(File.join(dir, 'canary-runs.json'), JSON.generate(history))
      runner = FakeCanary.new('[]')
      Shaka::Canary::Coverage.new(environment(dir), runner).commits
      assert_equal 'aaa1111^..abc123', runner.commands.last.last
    end
  end

  def test_an_outsider_cannot_spoof_the_previous_elapsed_time
    Dir.mktmpdir do |dir|
      spoof = timer_comment('outsider', 1)
      real = timer_comment('canary-bot', 123)
      runner = FakeCanary.new('[]', comments: [spoof, real])
      pulls = JSON.parse(list_body)
      bodies = Shaka::Canary::Coverage.new(environment(dir), runner).comments(pulls, pulls.first)
      assert_equal [real['body']], bodies
      assert_equal '123', Shaka::Canary::Summary.elapsed_marker(bodies)
    end
  end

  def timer_comment(login, elapsed)
    { 'user' => { 'login' => login },
      'body' => "#{Shaka::Canary::Summary::IDENTITY}\n\n<!-- shaka-canary elapsed_seconds=#{elapsed} spend=$1 -->" }
  end

  def test_unavailable_commenter_identity_keeps_the_comparison_unknown
    Dir.mktmpdir do |dir|
      runner = FakeCanary.new('[]', failure: 'user', comments: [timer_comment('outsider', 1)])
      pulls = JSON.parse(list_body)
      bodies = Shaka::Canary::Coverage.new(environment(dir), runner).comments(pulls, pulls.first)
      assert_empty bodies
      assert_equal 'UNKNOWN', Shaka::Canary::Summary.elapsed_marker(bodies)
    end
  end

  def test_the_first_run_names_only_its_selected_commit
    Dir.mktmpdir do |dir|
      runner = FakeCanary.new('[]')
      Shaka::Canary::Coverage.new(environment(dir), runner).commits
      assert_includes runner.commands.last, '-1'
      assert_equal 'abc123', runner.commands.last.last
    end
  end
end

class FakeCanaryHistory
  attr_reader :commands

  def initialize(response)
    @response = response
    @commands = []
  end

  def capture(argv)
    @commands << argv
    @response
  end
end

class FakeCanary
  attr_reader :commands

  def initialize(list, failure: '', comments: [], open_pulls: nil)
    @list = list
    @failure = failure
    @comments = comments
    @open_pulls = open_pulls
    @commands = []
  end

  def capture(argv, chdir: nil)
    @commands << argv
    @dir = chdir
    return { 'out' => '', 'err' => 'permission denied', 'ok' => false } if argv.include?(@failure)
    return { 'out' => @list, 'err' => '', 'ok' => true } if argv[0] == 'gh' && argv[2] == 'list'
    return { 'out' => 'deadbeef', 'err' => '', 'ok' => true } if argv.include?('rev-parse')
    return { 'out' => "abc123 Add canary\n", 'err' => '', 'ok' => true } if argv.include?('log')
    return api(argv) if argv[1] == 'api'

    { 'out' => "ok\n", 'err' => '', 'ok' => true }
  end

  def api(argv)
    pages = argv.last.include?('/pulls?') ? rest_open_pulls.each_slice(30).to_a : [@comments]
    pages = pages.first(1) unless argv.include?('--paginate')
    data = argv.include?('--slurp') ? pages : pages.first
    out = argv[2] == 'user' ? 'canary-bot' : JSON.generate(data)
    { 'out' => out, 'err' => '', 'ok' => true }
  end

  def rest_open_pulls
    (@open_pulls || JSON.parse(@list)).map do |pull|
      { 'number' => pull['number'], 'state' => pull['state'], 'created_at' => pull['createdAt'],
        'head' => { 'ref' => pull['headRefName'], 'repo' => { 'id' => pull['isCrossRepository'] ? 2 : 1 } },
        'base' => { 'repo' => { 'id' => 1 } } }
    end
  end
end

class CanaryTemplateTest < Minitest::Test
  def test_the_real_description_claim_branch_is_accepted_for_this_run
    path = File.expand_path('../templates/shaka-canary/.agents/shaka/config.yml', __dir__)
    template = YAML.load_file(path).dig('branches', 'name')
    name = Shaka::Claim::Names.new(query: nil, description: 'run-99-1', template: template).reported
    pull = { 'headRefName' => name, 'isCrossRepository' => false }

    assert_equal [pull], Shaka::Canary::Pulls.for_run([pull], name)
  end

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
