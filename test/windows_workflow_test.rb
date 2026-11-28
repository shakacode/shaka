# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'

class WindowsWorkflowTest < Minitest::Test
  PIN = /\A[0-9a-f]{40}\z/
  DOCS_GATE = "steps.changes.outputs.docs_only != 'true'"
  AFTER_RUBY = "!cancelled() && steps.ruby.outcome == 'success'"

  def setup
    @path = File.expand_path('../.github/workflows/windows.yml', __dir__)
    @workflow = YAML.load_file(@path)
    @validate = YAML.load_file(File.expand_path('../.github/workflows/validate.yml', __dir__))
    @job = @workflow.fetch('jobs').fetch('windows')
    @steps = @job.fetch('steps')
  end

  def test_runs_on_the_free_windows_runner_and_fails_when_a_step_fails
    on = @workflow['on'] || @workflow[true]

    assert_includes on.keys, 'pull_request'
    assert_equal ['main'], on.dig('push', 'branches')
    assert_equal 'windows-latest', @job.fetch('runs-on')
    refute @job.key?('continue-on-error')
    assert_equal 'read', @workflow.dig('permissions', 'contents')
    refute @workflow.key?('services')
  end

  def test_runs_the_full_suite_only_nightly_or_on_request
    on = @workflow['on'] || @workflow[true]
    suite = exercise_steps.find { |step| step['run'] == 'ruby bin/windows-exercise suite' }

    assert on.dig('schedule', 0, 'cron')
    assert on.key?('workflow_dispatch')
    nightly = "github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'"
    assert_equal "${{ #{AFTER_RUBY} && (#{nightly}) }}", suite['if']
    assert suite['continue-on-error']
  end

  def test_pins_the_same_checkout_and_ruby_actions_as_validate
    validate_steps = @validate.dig('jobs', 'validate', 'steps')

    assert_equal uses(validate_steps, 'actions/checkout'), uses(@steps, 'actions/checkout')
    assert_equal uses(validate_steps, 'ruby/setup-ruby'), uses(@steps, 'ruby/setup-ruby')
    assert_match PIN, pin('actions/checkout')
    assert_match PIN, pin('ruby/setup-ruby')
  end

  def test_installs_the_repository_ruby_with_bundler_cache
    assert_equal '.ruby-version', ruby_step.dig('with', 'ruby-version')
    assert ruby_step.dig('with', 'bundler-cache')
  end

  def test_exercises_doctor_repository_commands_and_the_cursor_hook
    runs = @steps.filter_map { |step| step['run'] }

    assert_includes runs, 'ruby bin/windows-exercise doctor'
    assert_includes runs, 'ruby bin/windows-exercise commands'
    assert_includes runs, 'ruby bin/windows-exercise cursor'
    assert_includes runs, 'ruby bin/windows-exercise suite'
  end

  def test_a_failing_quick_step_fails_the_check
    quick = @steps.reject { |step| step['run'] == 'ruby bin/windows-exercise suite' }

    assert_empty(quick.select { |step| step.key?('continue-on-error') })
  end

  def test_later_steps_still_run_after_an_earlier_failure_once_ruby_is_set_up
    later = @steps.drop(ruby_index + 1)

    assert(later.all? { |step| step['if'].start_with?("${{ #{AFTER_RUBY}") })
  end

  def test_names_the_suite_file_windows_ruby_cannot_load
    assert_includes File.read(@path), 'test/local_evaluation_probe_container_test.rb'
    assert_includes File.read(@path), 'pty'
  end

  def test_keeps_checkout_bytes_so_shebangs_stay_what_git_stored
    first = @steps.first
    checkout = @steps.index { |step| step['uses'].to_s.start_with?('actions/checkout@') }

    assert_includes first.fetch('run'), 'core.autocrlf false'
    assert_operator @steps.index(first), :<, checkout
  end

  def test_reports_on_every_pull_request_and_merge_group_so_main_can_require_it
    on = @workflow['on'] || @workflow[true]

    assert on.key?('merge_group')
    refute on['pull_request'].to_h.key?('paths-ignore')
    refute on['push'].to_h.key?('paths-ignore')
  end

  def test_detects_documentation_changes_like_validate
    assert_equal validate_job.dig('env', 'SHAKA_BASE_REF'), @job.dig('env', 'SHAKA_BASE_REF')
    assert_equal detector_run(validate_job.fetch('steps')), detector_run(@steps)
  end

  def test_detects_right_after_a_full_history_checkout
    checkout = @steps.index { |step| step['uses'].to_s.start_with?('actions/checkout@') }

    assert_equal 0, @steps.fetch(checkout).dig('with', 'fetch-depth')
    assert_equal checkout + 1, detector_index
  end

  def test_skips_every_step_after_detection_for_documentation
    assert_equal detector_index + 1, ruby_index
    assert_equal DOCS_GATE, @steps.fetch(ruby_index)['if']
    assert(@steps.drop(ruby_index + 1).all? { |step| step['if'].include?("steps.ruby.outcome == 'success'") })
  end

  private

  def validate_job = @validate.dig('jobs', 'validate')

  def ruby_index = @steps.index { |step| step['uses'].to_s.start_with?('ruby/setup-ruby@') }

  def detector_index = @steps.index { |step| step['id'] == 'changes' }

  def detector_run(steps) = steps.find { |step| step['id'] == 'changes' }.fetch('run')

  def uses(steps, name)
    steps.find { |step| step['uses'].to_s.start_with?("#{name}@") }.fetch('uses')
  end

  def exercise_steps = @steps.select { |step| step['run'].to_s.start_with?('ruby bin/windows-exercise') }

  def pin(name) = uses(@steps, name).split('@', 2).last.split(' ', 2).first

  def ruby_step = @steps.find { |step| step['uses'].to_s.start_with?('ruby/setup-ruby@') }
end
