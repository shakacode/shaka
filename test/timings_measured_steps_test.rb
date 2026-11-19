# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/call_log'
require 'shaka/publication/timings_details'

# The timings list each measured step a session recorded and carry them for the next update.
class TimingsMeasuredStepsTest < Minitest::Test
  include EvidenceFixture

  OPENED = Time.utc(2026, 10, 18, 8, 0)

  STEPS = [
    { 'id' => 'a' * 16, 'command' => 'evidence run', 'check' => 'validate', 'at' => '2026-10-18T08:05:00Z',
      'duration_ms' => 805_000, 'exit' => 0, 'machine' => 'm5' },
    { 'id' => 'b' * 16, 'command' => 'review run', 'at' => '2026-10-18T08:20:00Z', 'duration_ms' => 58_000,
      'exit' => 1, 'provider' => 'openai', 'model' => 'gpt-6.1-sol', 'effort' => 'medium' }
  ].freeze

  def test_measured_steps_follow_the_stretches_and_ride_hidden_for_the_next_update
    timeline = { 'opened' => OPENED, 'merged' => OPENED + 3600, 'labels' => [], 'steps' => STEPS }
    body = Shaka::TimingsDetails.new(timeline).detail['body']

    assert_includes body, '**Measured steps:** Validation 13m (1 run) · Local review 58s (1 run)'
    assert_equal STEPS, carried(body)
    assert_operator body.index('Between checkpoints'), :<, body.index('Measured steps')
  end

  # The bars show when each step ran, so only a step the reader must act on keeps its row.
  def test_the_bars_replace_rows_except_for_failed_steps_and_settings_move_to_one_line
    timeline = { 'opened' => OPENED, 'merged' => OPENED + 3600, 'labels' => [], 'steps' => STEPS }
    body = Shaka::TimingsDetails.new(timeline).detail['body']

    assert_operator body.index('```text'), :<, body.index('| Stretch |')
    assert_includes body, '**Failed or unfinished steps:**'
    assert_includes body, '| Local review | 2026-10-18 08:20 | 58s | not completed (exit 1) | ' \
                          'openai · gpt-6.1-sol · medium | UNKNOWN |'
    refute_includes body, '| Validation: validate |'
    assert_includes body, '**Models:** openai · gpt-6.1-sol · medium · **Machines:** m5, UNKNOWN'
  end

  def test_all_passing_steps_leave_no_step_table
    timeline = { 'opened' => OPENED, 'merged' => OPENED + 3600, 'labels' => [], 'steps' => [STEPS.first] }
    body = Shaka::TimingsDetails.new(timeline).detail['body']

    refute_includes body, '| Step |'
    refute_includes body, 'Failed or unfinished'
  end

  def test_a_chart_that_cannot_render_keeps_every_step_row
    finished = STEPS.last.merge('id' => 'c' * 16, 'command' => 'post-implementation run', 'exit' => 0)
    timeline = { 'opened' => OPENED, 'merged' => OPENED + 3600, 'labels' => [], 'steps' => [*STEPS, finished] }
    body = broken_chart.new(timeline).detail['body']

    refute_includes body, '```text'
    assert_includes body, '| Validation: validate | 2026-10-18 08:05 | 13m | passed | — | m5 |'
    assert_includes body, '| Local review | 2026-10-18 08:20 | 58s | not completed (exit 1) |'
    assert_includes body, '| Product checkpoint | 2026-10-18 08:20 | 58s | completed |'
  end

  def broken_chart
    Class.new(Shaka::TimingsDetails) do
      private

      def draw_bars(_rows, _steps) = raise(ArgumentError, 'bad')
    end
  end

  # A review or checkpoint exits 0 whatever it concluded, so an unfinished one never reads failed or passed.
  def test_an_unfinished_review_or_checkpoint_reads_not_completed
    checkpoint = STEPS.last.merge('command' => 'post-implementation run')
    body = Shaka::TimingsDetails.new({ 'unavailable' => 'x', 'steps' => [checkpoint] }).detail['body']

    assert_includes body, '| Product checkpoint | 2026-10-18 08:20 | 58s | not completed (exit 1) |'
    refute_includes body, 'passed'
  end

  # Steps are carried even when GitHub's timeline is missing, so one failed read loses none of them.
  def test_an_unavailable_timeline_still_carries_the_steps
    body = Shaka::TimingsDetails.new({ 'unavailable' => 'gh failed', 'steps' => STEPS }).detail['body']

    assert body.start_with?(Shaka::TimingsDetails::UNAVAILABLE)
    assert_includes body, '```text'
    assert_equal STEPS, carried(body)
  end

  def test_hidden_rows_and_dropped_steps_are_disclosed_and_carried
    many = (1..35).map { |index| STEPS.last.merge('id' => format('%016x', index)) }
    body = Shaka::TimingsDetails.new({ 'unavailable' => 'x', 'steps' => many, 'dropped_steps' => 4 }).detail['body']

    assert_includes body, 'Showing the latest 30 of 35 failed or unfinished steps. ' \
                          'The totals cover the latest 35; 4 older steps are no longer kept.'
    assert_equal [many, 4], Shaka::TimelineSteps.read("<!-- shaka:begin -->\n#{body}\n<!-- shaka:end -->")
  end

  # The measured steps find a validation run by this tree, which equals the commit's tree once the work is committed.
  def test_a_validation_run_records_the_tree_it_tested
    before = Shaka::CallLog.tags.dup
    with_checkout do |root, ref|
      result = run_check(root, ref)
      assert_equal [git(root, 'rev-parse', 'HEAD^{tree}')] * 2, [result['tested_tree'], Shaka::CallLog.tags['tree']]
    end
  ensure
    Shaka::CallLog.tags.replace(before)
  end

  private

  def carried(body) = Shaka::TimelineSteps.carried("<!-- shaka:begin -->\n#{body}\n<!-- shaka:end -->")
end
