# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'yaml'

class ReviewWorkflowTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir('review-result')
    @summary = File.join(@directory, 'summary.md')
    @execution = File.join(@directory, 'execution.json')
    workflow = YAML.load_file(File.expand_path('../.github/workflows/claude-code-review.yml', __dir__))
    steps = workflow.dig('jobs', 'claude-review', 'steps')
    @script = steps.find { |step| step.dig('env', 'EXECUTION_FILE') }.fetch('run')
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_missing_execution_is_prominently_unavailable_not_completed
    output, status, summary = run_result

    refute_predicate status, :success?
    assert_includes output, '::error::'
    assert_includes summary, 'UNAVAILABLE'
    refute_includes summary, 'COMPLETED'
  end

  def test_failed_action_is_visible_even_without_execution
    _output, status, summary = run_result(outcome: 'failure')

    refute_predicate status, :success?
    assert_includes summary, 'UNAVAILABLE'
  end

  def test_missing_malformed_and_failed_results_cannot_report_completed
    [[], '{broken', [{ type: 'result' }], [result.merge(is_error: true)],
     [result.merge(subtype: 'error_max_turns')], [result.merge(num_turns: 0)]].each do |data|
      _output, status, summary = run_result(data)
      refute_predicate status, :success?, data.inspect
      assert_includes summary, 'UNAVAILABLE'
      refute_includes summary, 'COMPLETED'
    end
  end

  def test_successful_execution_without_a_visible_review_fails
    _output, status, summary = run_result([result])

    refute_predicate status, :success?
    assert_includes summary, 'UNAVAILABLE'
  end

  def test_current_bot_report_completes_the_check
    output, status, summary = run_result([result], comments: [report])

    assert_predicate status, :success?, output
    assert_includes summary, '**VERIFIED**'
    assert_includes summary, 'a' * 40
  end

  def test_old_wrong_head_and_other_author_reports_fail
    [report.merge('created_at' => '2026-09-29T00:00:00Z'),
     report.merge('body' => 'b' * 40), report.merge('user' => { 'login' => 'other[bot]' })].each do |comment|
      _output, status, = run_result([result], comments: [comment])
      refute_predicate status, :success?
    end
  end

  def test_denials_name_tools_without_publishing_their_inputs
    denied = result.merge(permission_denials: [{ tool_name: 'Bash', tool_input: { command: 'private input' } }])
    _output, _status, summary = run_result([denied])

    assert_includes summary, 'Bash'
    refute_includes summary, 'private input'
  end

  def test_a_bot_comment_without_a_findings_count_does_not_satisfy_review
    comment = report.merge('body' => "Could not review #{'a' * 40}")
    _output, status, = run_result([result], comments: [comment])

    refute_predicate status, :success?
  end

  def test_an_unreadable_comment_api_does_not_satisfy_review
    install_github([])
    File.write(File.join(@directory, 'gh'), "#!/bin/sh\nexit 1\n")
    File.write(@execution, JSON.generate([result]))
    environment = result_environment([result])
    _output, status = Open3.capture2e(environment, 'bash', '-c', @script)

    refute_predicate status, :success?
  end

  private

  def result
    { type: 'result', subtype: 'success', is_error: false, num_turns: 2 }
  end

  def report
    { 'user' => { 'login' => 'claude[bot]' }, 'created_at' => '2026-09-30T00:01:00Z',
      'body' => "Review of #{'a' * 40}: no findings" }
  end

  def install_github(comments)
    File.write(File.join(@directory, 'comments.json'), JSON.generate([comments]))
    command = File.join(@directory, 'gh')
    File.write(command, "#!/bin/sh\ncat '#{@directory}/comments.json'\n")
    File.chmod(0o700, command)
  end

  def run_result(data = nil, outcome: 'success', comments: [])
    File.write(@execution, data.is_a?(String) ? data : JSON.generate(data)) unless data.nil?
    File.write(@summary, '')
    install_github(comments)
    environment = result_environment(data, outcome)
    output, status = Open3.capture2e(environment, 'bash', '-c', @script)
    [output, status, File.read(@summary)]
  end

  def result_environment(data, outcome = 'success')
    { 'BASH_ENV' => nil, 'PATH' => "#{@directory}:#{ENV.fetch('PATH')}",
      'GITHUB_REPOSITORY' => 'o/r', 'REVIEW_PR' => '1',
      'REVIEW_STARTED_AT' => '2026-09-30T00:00:00Z', 'EXECUTION_FILE' => data.nil? ? '' : @execution,
      'REVIEW_OUTCOME' => outcome,
      'REVIEW_HEAD' => 'a' * 40, 'GITHUB_STEP_SUMMARY' => @summary }
  end
end
