# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_ask'
require_relative 'support/evaluation_snapshot_fixture'
require_relative 'support/evaluation_ask_fixture'

class EvaluationCodexAskTest < Minitest::Test
  include EvaluationSnapshotFixture

  alias native_pull pull
  alias native_checks checks
  alias native_blobs blobs
  include EvaluationAskFixture

  def test_collects_unchanged_review_then_final_pr_without_promoting_capture
    result = collect
    packet = result.fetch('evidence')
    assert_operator packet.dig('current_walkthrough', 'readback_finished_at'), :>,
                    packet.dig('terminal', 'accepted_at')
    assert_equal 'OPEN', packet.dig('pull', 'state')
  end

  def test_preserves_preterminal_checks_and_keeps_capture_unavailable
    result = collect
    packet = result.fetch('evidence')
    refute packet.fetch('command_capture_complete')
    assert_equal 'UNKNOWN', packet.fetch('merge_attempts')
    assert_in_delta(4.0, packet.dig('checks', 0, 'observed_at'))
    refute result.dig('grading', 'passed')
    assert result.fetch('grading').fetch('assertions').except('no_merge').values.all?(true)
  end

  def test_changed_walkthrough_or_final_closed_pr_is_retained_as_failure
    row = walkthrough.fetch('review').merge('body' => 'changed')
    refute collect(review: row).dig('grading', 'assertions', 'walkthrough')
    closed = native_pull
    closed.dig('data', 'repository', 'pullRequest')['state'] = 'CLOSED'
    refute collect(final: closed).dig('grading', 'assertions', 'pr_open')
  end

  def test_wrong_review_or_moved_head_refuses_collection_and_cannot_retry
    row = walkthrough.fetch('review').merge('commit' => { 'oid' => 'd' * 40 })
    writer = Shaka::Evaluation::CodexAsk.new(plan, github: @gh)
    assert_raises(IOError) { collect(review: row, writer:) }
    assert_raises(ArgumentError) { collect(writer:) }
    moved = native_pull
    moved.dig('data', 'repository', 'pullRequest')['headRefOid'] = 'd' * 40
    assert_raises(IOError) { collect(final: moved) }
  end

  def test_inconsistent_changed_file_bounds_are_unavailable
    before = snapshot_before.merge('changed_files' => { 'lib/a space.rb' => 4 })
    assert_raises(IOError) { collect(before:) }
  end

  def test_final_collection_cannot_repair_preterminal_check_failure
    before = snapshot_before.merge('checks' => [check.merge('status' => 'in_progress')])
    assert_raises(IOError) { collect(before:) }
    refute_path_exists File.join(@directory, 'requests')
  end

  def test_declared_check_app_names_must_match_required_checks
    assert_raises(ArgumentError) do
      Shaka::Evaluation::CodexAsk.new(plan.merge('check_apps' => { 'other' => 15_368 }), github: @gh)
    end
  end

  private

  def plan
    { 'repository' => REPOSITORY, 'number' => 1, 'head' => HEAD, 'check_apps' => { 'validate' => 15_368 },
      'machine_actor' => 'fixture-agent', 'driver_actor' => 'fixture-driver',
      'required_checks' => ['validate'], 'clock_id' => 'process-1' }
  end

  def walkthrough
    receipt(22, 'fixture-agent', walkthrough_body.sub('lib/code.rb', 'lib/a%20space.rb'), 3.0)
  end

  def snapshot_before = { 'checks' => [check], 'changed_files' => { 'lib/a space.rb' => 3 } }

  def driver_result
    entry = verification.merge('clock_id' => 'process-1', 'verification' => { 'clock_id' => 'process-1' })
    terminal = evidence.fetch('terminal').except('accepted_at').merge('native_item_id' => 'native-final')
    { 'capture' => { 'clock_id' => 'process-1', 'transport_status' => 'completed', 'native_status' => 'completed',
                     'exit_code' => 0, 'terminal' => terminal, 'turn_ended_at' => 11.0, 'observed_at' => 12.0 },
      'verifications' => [entry] }
  end

  def collect(review: walkthrough.fetch('review'), final: native_pull, before: snapshot_before,
              writer: Shaka::Evaluation::CodexAsk.new(plan, github: @gh))
    rows = [{ 'data' => { 'node' => review } }, native_pull, native_checks, native_blobs, final]
    File.write(File.join(@directory, 'responses'), JSON.generate(rows))
    FileUtils.rm_f(File.join(@directory, 'index'))
    writer.collect(driver_result:, before:, walkthrough:)
  end
end
