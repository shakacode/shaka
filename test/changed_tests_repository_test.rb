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

  # bin/docs-only-change no longer forces the whole suite for this guide; this selection replaces that.
  def test_this_repository_selects_the_skill_test_for_the_maintenance_guide
    assert_includes ChangedTests.new(ROOT).tests_for([%w[M internal/improving-shaka.md]]), 'test/skill_test.rb'
  end

  def test_this_repository_selects_the_tests_that_read_a_guide
    selected = ChangedTests.new(ROOT).tests_for([%w[M docs/settings.md]])

    assert_includes selected, 'test/configure_settings_test.rb'
    # Library files name the page only in links, so the selection stays a small share of the suite.
    assert_operator selected.size, :<, Dir.glob('test/**/*_test.rb', base: ROOT).size / 4
  end
end
