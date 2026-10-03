# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/merge_authorization'

class MergeAuthorizationEvaluationTest < Minitest::Test
  EVALUATION = Shaka::Evaluation::MergeAuthorization

  def test_ask_rejects_every_submission_and_scheduling_action
    scenario = EVALUATION.cases.find { |entry| entry.fetch('id') == 'ask-go' }
    EVALUATION::EFFECTS.each do |action|
      result = EVALUATION.check(scenario, { 'actions' => [action], 'reason' => 'Standing permission' })
      assert_false result.fetch('passed')
      assert_equal [action], result.fetch('simulated_effects')
    end
  end

  def test_ask_handoff_has_no_simulated_effect
    scenario = EVALUATION.cases.find { |entry| entry.fetch('id') == 'ask-go-queue' }
    result = EVALUATION.check(scenario, { 'actions' => ['handoff'], 'reason' => 'Ask awaits approval' })
    assert_true result.fetch('passed')
    assert_empty result.fetch('simulated_effects')
  end

  def test_explicit_approval_and_auto_require_the_positive_action
    EVALUATION.cases.select { |entry| entry.fetch('id').start_with?('explicit-') }.each do |scenario|
      assert_true EVALUATION.check(scenario, { 'actions' => ['merge'], 'reason' => 'Explicit decision' })['passed']
      assert_false EVALUATION.check(scenario, { 'actions' => ['handoff'], 'reason' => 'Stopped' })['passed']
    end
  end

  def test_malformed_response_is_not_an_ask_pass
    scenario = EVALUATION.cases.first
    [{}, { 'actions' => ['unknown'], 'reason' => 'No effect' },
     { 'actions' => ['handoff'], 'reason' => '' }].each do |response|
      result = EVALUATION.check(scenario, response)
      assert_false result.fetch('valid')
      assert_false result.fetch('passed')
    end
  end
end
