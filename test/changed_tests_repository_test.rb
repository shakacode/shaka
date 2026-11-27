# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/changed_tests'

# Selections for this repository's own files.
class ChangedTestsRepositoryTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  # The real suite starts the helper through SHAKA_COMMAND from the test helper.
  def test_this_repository_selects_helper_tests_for_a_file_the_helper_loads
    selected = ChangedTests.new(ROOT).tests_for([%w[M skills/shaka/lib/shaka/merge_risk_gate.rb]])

    assert_includes selected, 'test/merge_risk_gate_test.rb'
    assert_includes selected, 'test/cli_merge_risk_test.rb'
  end

  # RunTestsTest reaches the worker split only through the runner, so a change to it runs everything.
  def test_this_repository_runs_the_whole_suite_for_a_worker_split_change
    assert_nil ChangedTests.new(ROOT).tests_for([%w[M test/support/worker_plan.rb]])
  end

  def test_this_repository_selects_a_strict_subset_for_instruction_and_settings_changes
    selected = ChangedTests.new(ROOT).tests_for([%w[M AGENTS.md], %w[M .agents/shaka/config.yml]])

    refute_nil selected
    assert_operator selected.size, :<, Dir.glob('test/**/*_test.rb', base: ROOT).size
  end
end
