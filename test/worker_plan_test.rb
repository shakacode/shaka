# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/worker_plan'
require 'fileutils'

class WorkerPlanTest < Minitest::Test
  NAMES = %w[A B C D E F].freeze

  def test_without_a_record_worker_n_keeps_every_nth_class_by_name
    assert_equal [%w[A C E], %w[B D F]], WorkerPlan.assign(NAMES.reverse, 2, {})
  end

  def test_recorded_times_give_the_longest_class_to_the_least_loaded_worker
    seconds = { 'A' => 9.0, 'B' => 1.0, 'C' => 1.0, 'D' => 1.0, 'E' => 4.0, 'F' => 4.0 }

    assert_equal [%w[A C], %w[E F B D]], WorkerPlan.assign(NAMES, 2, seconds)
  end

  def test_every_class_lands_in_exactly_one_share_when_the_record_is_stale
    seconds = { 'A' => 3.0, 'Gone' => 50.0, 'F' => 0.5 }
    shares = WorkerPlan.assign(NAMES, 4, seconds)

    assert_equal NAMES, shares.flatten.sort
    assert_equal 4, shares.size
  end

  def test_more_workers_than_classes_leaves_some_shares_empty
    assert_equal [%w[A], %w[B], []], WorkerPlan.assign(%w[A B], 3, { 'A' => 1.0 })
  end

  def test_a_whole_suite_run_replaces_the_record_and_a_partial_run_updates_it
    Dir.mktmpdir('worker-plan') do |directory|
      path = File.join(directory, 'times.json')
      WorkerPlan.write(path, { 'A' => 1.0, 'Old' => 2.0 }, whole: true)
      WorkerPlan.write(path, { 'A' => 3.0, '' => 9.0 }, whole: false)

      assert_equal({ 'A' => 3.0, 'Old' => 2.0 }, WorkerPlan.read(path))
      WorkerPlan.write(path, { 'B' => 4.0 }, whole: true)

      assert_equal({ 'B' => 4.0 }, WorkerPlan.read(path))
    end
  end

  def test_a_missing_or_malformed_record_reads_as_empty
    Dir.mktmpdir('worker-plan') do |directory|
      path = File.join(directory, 'times.json')

      assert_empty WorkerPlan.read(path)
      File.write(path, '{not json')

      assert_empty WorkerPlan.read(path)
      File.write(path, '{"A": "slow", "B": 2.0}')

      assert_equal({ 'B' => 2.0 }, WorkerPlan.read(path))
    end
  end

  # Git prints the common directory relative to the main checkout but absolute in a linked worktree.
  def test_a_checkout_and_its_linked_worktree_share_one_record_in_the_common_git_directory
    Dir.mktmpdir('worker-plan') do |directory|
      main = File.join(directory, 'main')
      git('init', '-q', main)
      git('-C', main, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
          'commit', '-q', '--allow-empty', '-m', 'start')
      git('-C', main, 'worktree', 'add', '-q', File.join(directory, 'linked'))
      expected = File.join(File.realpath(File.join(main, '.git')), 'shaka-test-durations.json')

      paths = %w[main linked].map { record_path_in(File.join(directory, it)) }

      assert_equal [expected] * 2, paths
    end
  end

  def test_outside_a_repository_or_without_git_there_is_no_record
    Dir.mktmpdir('worker-plan') do |directory|
      assert_nil record_path_in(directory)
      assert_nil record_path_in(Dir.pwd, 'PATH' => directory)
    end
  end

  private

  def git(*args)
    _, status = Open3.capture2e('git', *args)

    assert_predicate status, :success?, args.inspect
  end

  def record_path_in(root, env = {})
    saved = ENV.to_h.slice('SHAKA_TEST_DURATIONS', *env.keys)
    ENV.delete('SHAKA_TEST_DURATIONS')
    ENV.update(env)
    path = WorkerPlan.record_path(root)
    path && File.join(File.realpath(File.dirname(path)), File.basename(path))
  ensure
    ENV.delete('SHAKA_TEST_DURATIONS')
    ENV.update(saved)
  end
end
