# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_approval'
require_relative 'support/evaluation_ask_fixture'

class EvaluationAskMechanicsTest < Minitest::Test
  include EvaluationAskFixture

  def test_default_ask_still_refuses_shared_identities
    assert_raises(ArgumentError) { Shaka::Evaluation::CodexApproval.new(plan) }
    assert_raises(ArgumentError) { Shaka::Evaluation::DeliveryAsk.new(plan) }
    assert_raises(ArgumentError) { Shaka::Evaluation::DeliveryAsk.new(plan, mechanics: 'true') }
  end

  def test_explicit_single_account_probe_accepts_but_cannot_pass_measured_ask
    assert acceptance.fetch('mechanics_only')
  end

  def test_mechanics_can_never_pass_measured_ask_even_with_complete_inventory
    packet = mechanics_packet
    result = Shaka::Evaluation::DeliveryAsk.new(plan, mechanics: true).call(packet)
    refute result.fetch('passed')
    refute result.fetch('assertions').fetch('no_merge')
    assert result.fetch('assertions').except('no_merge').values.all?(true)
  end

  def test_mechanics_mode_keeps_timing_and_marker_prerequisites
    writer = Shaka::Evaluation::CodexApproval.new(plan, mechanics: true, clock: -> { 20.0 })
    result = driver_result
    result['capture']['terminal']['received_at'] = 5.0
    assert_raises(IOError) do
      writer.accept(driver_result: result, checks: [check], walkthrough: walkthrough,
                    changed_files: evidence.fetch('changed_files'))
    end
  end

  private

  def mechanics_packet
    evidence.merge(acceptance).merge(
      'verifications' => driver_result.fetch('verifications'), 'walkthrough' => walkthrough,
      'current_walkthrough' => walkthrough.merge('readback_finished_at' => 21.0)
    )
  end

  def acceptance
    Shaka::Evaluation::CodexApproval.new(plan, mechanics: true, clock: -> { 20.0 }).accept(
      driver_result:, checks: [check], walkthrough:, changed_files: evidence.fetch('changed_files')
    )
  end

  def plan
    { 'repository' => REPOSITORY, 'number' => 1, 'head' => HEAD, 'machine_actor' => 'fixture-driver',
      'driver_actor' => 'fixture-driver', 'required_checks' => ['validate'], 'clock_id' => 'process-1' }
  end

  def walkthrough = receipt(22, 'fixture-driver', walkthrough_body, 3.0)

  def driver_result
    entry = verification.merge('clock_id' => 'process-1', 'verification' => { 'clock_id' => 'process-1' })
    terminal = evidence.fetch('terminal').except('accepted_at').merge('native_item_id' => 'native-final')
    { 'capture' => { 'clock_id' => 'process-1', 'transport_status' => 'completed', 'native_status' => 'completed',
                     'exit_code' => 0, 'terminal' => terminal, 'turn_ended_at' => 11.0, 'observed_at' => 12.0 },
      'verifications' => [entry] }
  end
end
