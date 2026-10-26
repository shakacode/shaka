# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/canary/gate'
require 'shaka/canary/pulls'
require 'shaka/canary/body'
require 'shaka/canary/text'
require 'shaka/canary/report'

class CanaryBodyTest < Minitest::Test
  BODY = <<~BODY
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

  def test_a_rendered_description_has_no_issues
    assert_empty Shaka::Canary::BodyCheck.issues(BODY)
  end

  def test_unresolved_tokens_missing_sections_and_the_stats_line_fail
    issues = Shaka::Canary::BodyCheck.issues("Hello {{sha}}\n")

    assert_includes issues, 'unresolved {{token}}'
    assert_includes issues, 'missing section ## Summary'
    assert_includes issues, 'missing stats line (issue 899)'
  end

  def test_a_broken_table_and_a_broken_link_fail
    body = "#{BODY}\n| Check | Result |\n| only one |\n\nSee [docs]().\n"
    issues = Shaka::Canary::BodyCheck.issues(body)

    assert_includes issues, 'table rows have different column counts'
    assert_includes issues, 'broken link'
  end

  def test_a_table_without_a_separator_fails
    body = "#{BODY}\n| Check | Result |\n| body | pass |\n"
    assert_includes Shaka::Canary::BodyCheck.issues(body), 'table is missing its separator row'
  end

  def test_previous_body_diff_is_empty_only_when_the_text_matches
    assert_equal 'No previous canary PR body.', Shaka::Canary::BodyDiff.report(nil, BODY)
    assert_equal 'Canary PR body matches the previous run.', Shaka::Canary::BodyDiff.report(BODY, BODY)
    assert_includes Shaka::Canary::BodyDiff.report("#{BODY}\nextra\n", BODY), '--- previous'
  end

  def test_summary_fences_diffs_even_when_the_body_contains_long_code_fences
    raw = "--- previous\n+++ current\n@@ -1 +1 @@\n-<details>old</details>\n+``````ruby\n+new\n+``````\n"
    shown = Shaka::Canary::Summary.diff('diff' => raw)

    assert_equal "```````diff\n#{raw}```````", shown
  end

  def test_summary_closes_truncated_diffs_and_leaves_status_messages_unfenced
    raw = "--- previous\n+++ current\n#{"+line\n" * 90}"
    shown = Shaka::Canary::Summary.diff('diff' => raw)

    assert shown.start_with?("````diff\n--- previous\n")
    assert shown.end_with?("… diff truncated\n````")
    assert_equal(80, shown.lines.count { |line| line.start_with?('---', '+++', '+line') })
    ['No previous canary PR body.', 'Canary PR body matches the previous run.'].each do |message|
      assert_equal message, Shaka::Canary::Summary.diff('diff' => message)
    end
  end
end

class CanaryScheduleTest < Minitest::Test
  def test_push_runs_wait_until_an_hour_after_the_previous_success
    now = Time.utc(2026, 10, 26, 12, 0, 0)
    last = now - 600

    assert_equal 3000, Shaka::Canary::Throttle.wait_seconds(last_finished_at: last, now: now, manual: false)
    assert_equal 0, Shaka::Canary::Throttle.wait_seconds(last_finished_at: last, now: now, manual: true)
    assert_equal 0, Shaka::Canary::Throttle.wait_seconds(last_finished_at: nil, now: now, manual: false)
  end

  def test_a_finished_hour_does_not_add_more_waiting
    now = Time.utc(2026, 10, 26, 12, 0, 0)

    assert_equal 0, Shaka::Canary::Throttle.wait_seconds(last_finished_at: now - 3600, now: now, manual: false)
  end

  def test_latest_finish_uses_the_newest_timestamp
    runs = [{ 'updatedAt' => '2026-10-26T10:00:00Z' }, { 'updatedAt' => '2026-10-26T11:00:00Z' }, {}]

    assert_equal Time.iso8601('2026-10-26T11:00:00Z'), Shaka::Canary::Throttle.latest_finish(runs)
  end

  def test_cleanup_keeps_the_newest_open_pull_requests_and_the_current_one
    pulls = (1..6).map { |number| pull(number, 'OPEN') }

    closed = Shaka::Canary::Pulls.closable(pulls, keep: 5).map { |item| item['number'] }
    assert_equal [1], closed
    kept = Shaka::Canary::Pulls.closable(pulls, keep: 1, current: 6).map { |item| item['number'] }
    refute_includes kept, 6
  end

  def test_the_run_selects_a_pull_request_opened_after_it_started
    pulls = [pull(2, 'OPEN', '2026-10-26T12:30:00Z'), pull(1, 'OPEN', '2026-10-26T11:00:00Z')]
    found = Shaka::Canary::Pulls.newest_since(pulls, Time.iso8601('2026-10-26T12:00:00Z'))

    assert_equal 2, found['number']
    assert_equal 1, Shaka::Canary::Pulls.previous(pulls, 2)['number']
  end

  def pull(number, state, created = "2026-10-26T12:0#{number}:00Z")
    { 'number' => number, 'state' => state, 'createdAt' => created, 'body' => '', 'url' => "https://example/#{number}" }
  end
end

class CanaryPreflightTest < Minitest::Test
  SECRET = 'sentinel-model-key-do-not-print'

  def test_missing_settings_skip_without_copying_the_secret
    result = Shaka::Canary::Preflight.decide({ 'SHAKA_CANARY_MODEL_KEY' => SECRET })
    encoded = JSON.generate(result)

    assert_equal 'skip', result['action']
    assert_includes result['notice'], 'vars.SHAKA_CANARY_REPO'
    assert_includes result['notice'], 'secrets.SHAKA_CANARY_TOKEN'
    refute_includes encoded, SECRET
  end

  def test_a_complete_configuration_runs_and_an_invalid_one_does_not
    env = { 'SHAKA_CANARY_REPO' => 'shakacode/shaka-canary', 'SHAKA_CANARY_MODEL_KEY' => SECRET,
            'SHAKA_CANARY_TOKEN' => 'token' }

    assert_equal 'run', Shaka::Canary::Preflight.decide(env)['action']
    assert_equal 5, Shaka::Canary::Preflight.decide(env)['keep']
    assert_equal 'invalid', Shaka::Canary::Preflight.decide(env.merge('SHAKA_CANARY_REPO' => 'nope'))['action']
    assert_equal 'invalid', Shaka::Canary::Preflight.decide(env.merge('SHAKA_CANARY_KEEP' => '0'))['action']
  end

  def test_preflight_output_names_the_action_and_not_the_secret
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'output')
      env = ENV.to_h.merge('GITHUB_OUTPUT' => path, 'SHAKA_CANARY_REPO' => '', 'SHAKA_CANARY_MODEL_KEY' => SECRET,
                           'SHAKA_CANARY_TOKEN' => '')
      _out, status = Open3.capture2(env, RbConfig.ruby, File.expand_path('../bin/canary', __dir__), 'preflight')
      written = File.read(path)

      assert_equal 0, status.exitstatus
      assert_includes written, 'action=skip'
      refute_includes written, SECRET
    end
  end
end

class CanaryReportTest < Minitest::Test
  def test_the_prompt_repeats_the_same_task_for_the_merged_commit
    text = Shaka::Canary::Prompt.render(sha: 'abc123', repo: 'shakacode/shaka-canary')

    assert_includes text, 'abc123'
    assert_includes text, 'farewell'
    assert_includes text, 'Do not merge'
  end

  def test_a_run_without_a_pull_request_fails_and_names_the_commit
    result = Shaka::Canary::Report.build(input([]))

    assert_false result['ok']
    assert_includes result['summary'], 'no canary pull request'
    assert_includes result['summary'], 'https://github.com/shakacode/shaka/commit/abc123'
    assert_includes result['summary'], '🤖 AGENT · github-actions · canary · UNKNOWN'
  end

  def test_passing_checks_record_spend_and_the_previous_run
    result = Shaka::Canary::Report.build(passing_input)

    assert_true result['ok']
    assert_equal [1], result['close']
    assert_includes result['summary'], 'Spend $1.00. Previous run $0.50.'
    assert_includes result['summary'], 'Previous run 2m 3s.'
    assert_includes result['summary'], '--- previous'
  end

  def passing_input
    body = CanaryBodyTest::BODY
    pulls = [pull(2, body, '2026-10-26T12:30:00Z'), pull(1, body.sub('$1.00', '$0.50'), '2026-10-26T11:00:00Z')]
    input(pulls, checks: passing_checks, comments: [marker])
  end

  def input(pulls, checks: [], comments: [])
    { 'pulls' => pulls, 'started_at' => '2026-10-26T12:00:00Z', 'finished_at' => '2026-10-26T12:40:00Z',
      'shaka_sha' => 'abc123', 'shaka_repo' => 'shakacode/shaka', 'run_url' => 'https://example/run',
      'commits' => ['abc123 Add canary'], 'keep' => 1, 'command_checks' => checks, 'previous_comments' => comments }
  end

  def pull(number, body, created)
    { 'number' => number, 'state' => 'OPEN', 'createdAt' => created, 'body' => body, 'url' => "https://example/#{number}" }
  end

  def passing_checks
    Shaka::Canary::Report::COMMANDS.map { |name| { 'name' => name, 'ok' => true, 'detail' => 'ok' } }
  end

  def marker = "<!-- shaka-canary elapsed_seconds=123 spend=$0.50 -->\n"
end
