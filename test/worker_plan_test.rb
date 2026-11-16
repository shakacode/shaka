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
end
