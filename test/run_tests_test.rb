# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/run_tests_fixture'
require 'fileutils'
require 'json'

class RunTestsTest < Minitest::Test
  include RunTestsFixture

  def setup
    @directory = Dir.mktmpdir('run-tests').tap { FileUtils.mkdir_p(File.join(it, 'test')) }
    @marker = File.join(@directory, 'ran.txt')
    @durations = File.join(@directory, 'durations.json')
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_without_a_record_workers_split_classes_by_name_and_run_each_test_once
    assert_each_test_runs_once(%w[alpha gamma], %w[beta], split: 'split by class name')
  end

  def test_a_recorded_slow_class_gets_a_worker_of_its_own_and_each_test_still_runs_once
    File.write(@durations, '{"AlphaFixtureTest":10.0,"BetaFixtureTest":1.0,"GammaFixtureTest":1.0}')

    assert_each_test_runs_once(%w[alpha], %w[beta gamma], split: 'balanced by recorded class times')
  end

  def test_a_partial_run_updates_the_record_and_a_whole_suite_run_replaces_it
    file = fixture('alpha', %w[one])
    File.write(@durations, '{"RemovedTest":1.0}')
    [[[file], %w[AlphaFixtureTest RemovedTest]], [[], %w[AlphaFixtureTest]]].each do |files, recorded|
      output, status = run_tests(files, workers: 1)

      assert_predicate status, :success?, output
      assert_equal recorded, JSON.parse(File.read(@durations)).keys
    end
  end

  def test_a_failure_in_any_worker_fails_the_run_and_keeps_the_record
    files = [fixture('alpha', %w[one]), fixture('beta', %w[one], failing: true)]
    File.write(@durations, '{"AlphaFixtureTest":2.0}')
    output, status = run_tests(files, workers: 2)

    refute_predicate status, :success?
    assert_includes output, 'beta one failed'
    assert_equal({ 'AlphaFixtureTest' => 2.0 }, JSON.parse(File.read(@durations)))
  end

  def test_failing_classes_are_named_and_written_to_the_phase_log
    skipped = File.join(@directory, 'skipped_test.rb')
    File.write(skipped, "require 'minitest/autorun'\nclass SkippedFixtureTest < Minitest::Test\n  " \
                        "def test_later = skip('later')\nend\n")
    files = [fixture('alpha', %w[one]), fixture('beta', %w[one two], failing: true), skipped]
    log = File.join(@directory, 'phases.jsonl')
    output, = run_tests(files, workers: 2, env: { 'SHAKA_PHASE_LOG' => log })

    assert_includes output, 'Failing test classes: BetaFixtureTest'
    assert_equal([{ 'failed_tests' => ['BetaFixtureTest'] }], File.readlines(log).map { JSON.parse(it) })
  end

  def test_a_worker_that_cannot_load_its_files_fails_the_run
    broken = File.join(@directory, 'broken_test.rb')
    File.write(broken, "raise 'cannot load'\n")
    output, status = run_tests([fixture('alpha', %w[one]), broken], workers: 2)

    refute_predicate status, :success?
    assert_includes output, 'cannot load'
  end

  # Break caught: without a shell locale, workers ran as US-ASCII and the runner crashed
  # reading their UTF-8 output.
  def test_workers_without_a_shell_locale_run_and_report_as_utf8
    output, status = run_tests([locale_fixture], workers: 1, env: { 'LANG' => nil, 'LC_ALL' => nil, 'LC_CTYPE' => nil })

    assert_predicate status, :success?, output
    assert_includes output, 'Total: 1 runs'
  end

  # Break caught: decoding worker output as UTF-8 replaced bytes from a worker under another locale.
  def test_worker_output_in_another_encoding_reaches_the_report_unchanged
    output, status = run_tests([latin1_fixture], workers: 1)

    assert_predicate status, :success?, output.b
    assert_includes output.b, "caf\xE9".b
  end

  private

  def assert_each_test_runs_once(*workers, split:)
    files = %w[alpha beta gamma].map { |name| fixture(name, %w[one two]) }
    log = File.join(@directory, 'phases.jsonl')
    output, status = run_tests(files, workers: 2, env: { 'SHAKA_PHASE_LOG' => log })

    assert_predicate status, :success?, output
    refute_path_exists log, 'A passing run names no failing classes'
    assert_equal workers, workers_ran
    assert_equal %w[alpha beta gamma].product(%w[one two]).map { it.join('#') }, tests_ran
    assert_match(/^Total: 6 runs, .* across 2 workers, #{split}$/, output)
  end
end
