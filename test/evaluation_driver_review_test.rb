# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/driver_review'
require_relative '../eval/lib/shaka/evaluation/delivery_ask'
require_relative 'support/evaluation_delivery_fixture'

class EvaluationDriverReviewTest < Minitest::Test
  include EvaluationDeliveryFixture

  def setup
    super
    source = File.read(File.expand_path('fixtures/evaluation_delivery/driver_gh.txt', __dir__))
    File.write(@gh, "#!#{RbConfig.ruby}\n#{source}")
    File.write(File.join(@directory, 'mode'), '')
  end

  def test_protected_result_posts_a_pinned_comment_and_returns_only_readback_evidence
    entry = run_driver
    assert_equal HEAD, File.read(File.join(@directory, 'verified-head'))
    assert_equal 0, entry.dig('verification', 'exit_code')
    assert_equal HEAD, entry.fetch('head')
    assert_equal 'driver-clock', entry.fetch('clock_id')
    assert_operator entry.fetch('post_completed_at'), :<, entry.dig('receipt', 'readback_finished_at')
    assert_pinned_post(entry)
  end

  def test_nonzero_verification_posts_fail_without_approving_or_merging
    entry = run_driver(body: 'exit 7')
    assert_equal 7, entry.dig('verification', 'exit_code')
    assert_includes entry.dig('receipt', 'review', 'body'), "driver-verification: FAIL head=#{HEAD}"
    assert_equal(['COMMENT'], calls.filter_map { it.dig('request', 'event') })
  end

  def test_head_movement_before_verification_prevents_execution_and_publication
    File.write(File.join(@directory, 'moved'), 'yes')
    assert_raises(IOError) { run_driver }
    refute_path_exists File.join(@directory, 'verified-head')
    refute_path_exists File.join(@directory, 'posted.json')
  end

  def test_signal_exit_cannot_publish_a_pass
    entry = run_driver(body: "Process.kill('TERM', Process.pid)")
    assert_nil entry.dig('verification', 'exit_code')
    assert_includes entry.dig('receipt', 'review', 'body'), 'driver-verification: FAIL'
  end

  def test_head_movement_during_verification_prevents_publication
    assert_raises(IOError) { run_driver(body: "File.write('moved', 'yes')") }
    refute_path_exists File.join(@directory, 'posted.json')
  end

  def test_moved_head_or_changed_review_after_post_never_returns_evidence
    %w[move_after_post edited_body wrong_actor ambiguous_post].each do |mode|
      File.write(File.join(@directory, 'mode'), mode)
      assert_raises(IOError, mode) { run_driver }
      FileUtils.rm_f(File.join(@directory, 'moved'))
      FileUtils.remove_entry(File.join(@directory, 'verification'))
    end
  end

  def test_ambiguous_publication_is_not_retried_on_the_same_instance
    File.write(File.join(@directory, 'mode'), 'ambiguous_post')
    writer = driver
    assert_raises(IOError) { run_driver(writer:) }
    assert_raises(ArgumentError) { run_driver(writer:) }
    assert_equal(1, calls.count { it.fetch('argv').include?('POST') })
  end

  def test_verifier_timeout_leaves_no_post_and_reaps_the_child
    assert_raises(IOError) do
      run_driver(body: "File.write('pid', Process.pid); sleep 30", writer: driver(seconds: 0.5))
    end
    pid = Integer(File.read(File.join(@directory, 'pid')))
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
    refute_path_exists File.join(@directory, 'posted.json')
  end

  def test_invalid_counts_are_refused_before_native_work
    assert_raises(ArgumentError) { run_driver(attempt: 2, executions: 1) }
    refute_path_exists File.join(@directory, 'calls.jsonl')
  end

  def test_readback_entry_can_feed_the_existing_driver_assertion_without_qualifying_delivery
    entry = run_driver
    terminal = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    packet = { 'clock_id' => 'driver-clock', 'verifications' => [entry],
               'terminal' => { 'received_at' => terminal, 'accepted_at' => terminal } }
    criteria = driver_plan.merge('machine_actor' => 'fixture-machine', 'required_checks' => ['validate'])
    result = Shaka::Evaluation::DeliveryAsk.new(criteria).call(packet)
    assert result.dig('assertions', 'driver_pass')
    refute result.fetch('passed')
  end

  private

  def driver(seconds: 5)
    environment = { 'SHAKA_EVAL_HEAD' => 'cannot override the pin' }
    Shaka::Evaluation::DriverReview.new(driver_plan, github: @gh, environment:, seconds:)
  end

  def driver_plan
    { 'repository' => 'fixture-org/cell', 'number' => 1, 'head' => HEAD,
      'driver_actor' => 'fixture-agent', 'clock_id' => 'driver-clock' }
  end

  def run_driver(body: "File.write('verified-head', ENV.fetch('SHAKA_EVAL_HEAD'))", writer: driver,
                 attempt: 1, executions: 1)
    writer.run(command: [RbConfig.ruby, '-e', body], cwd: @directory,
               directory: File.join(@directory, 'verification'), attempt:, executions:)
  end

  def calls = File.readlines(File.join(@directory, 'calls.jsonl')).map { JSON.parse(it) }

  def assert_pinned_post(entry)
    posted = JSON.parse(File.read(File.join(@directory, 'posted.json')))
    assert_equal ['COMMENT', HEAD], posted.values_at('event', 'commit_id')
    assert_equal posted.fetch('body'), entry.dig('receipt', 'review', 'body')
    assert_includes posted.fetch('body'), "driver-verification: PASS head=#{HEAD} attempt=1 executions=1"
    assert_equal(2, calls.count { it.fetch('argv').include?('GET') })
  end
end
