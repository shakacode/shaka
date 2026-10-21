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
    assert_includes body, '| Validation: validate | 2026-10-18 08:05 | 13m | passed | — | m5 |'
    assert_includes body, '| Local review | 2026-10-18 08:20 | 58s | failed (exit 1) | ' \
                          'openai · gpt-6.1-sol · medium | UNKNOWN |'
    assert_equal STEPS, carried(body)
    assert_operator body.index('Between checkpoints'), :<, body.index('Measured steps')
  end

  # Steps are carried even when GitHub's timeline is missing, so one failed read loses none of them.
  def test_an_unavailable_timeline_still_carries_the_steps
    body = Shaka::TimingsDetails.new({ 'unavailable' => 'gh failed', 'steps' => STEPS }).detail['body']

    assert body.start_with?(Shaka::TimingsDetails::UNAVAILABLE)
    assert_equal STEPS, carried(body)
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
