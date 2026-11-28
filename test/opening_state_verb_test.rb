# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require_relative '../skills/shaka/lib/shaka/opening_check'

# A first sentence that only keeps a state hides the change; the verdict flags it from the parse alone.
class OpeningStateVerbTest < Minitest::Test
  def test_flags_a_state_verb_that_hides_actions
    # The parse a model returned for the opening of #1331.
    result = verdict('A pull request', 'keeps', ['deciding'])

    assert_equal 'flagged', result['status']
    refute result['terms_only']
    assert_includes result['reason'], '"keeps"'
    assert_includes result['reason'], '"deciding"'
  end

  def test_flags_a_state_verb_after_a_modifier
    ['no longer keeps', 'still has', 'Remains'].each do |action|
      assert_equal 'flagged', verdict('A pull request', action, ['publishing'])['status'], action
    end
  end

  def test_passes_a_state_verb_with_no_hidden_actions
    assert_equal 'passed', verdict('A pull request', 'keeps', [])['status']
  end

  def test_passes_an_event_verb_with_hidden_actions
    ['no longer deletes', 'has stopped deleting', 'is marked', 'keeps publishing'].each do |action|
      assert_equal 'passed', verdict('A pull request', action, ['republishing'])['status'], action
    end
  end

  def test_an_internal_subject_is_reported_before_a_state_verb
    result = verdict('The helper', 'keeps', ['deciding'], reader_facing: false)

    assert_includes result['reason'], 'is not something a maintainer cares about'
    refute_includes result['reason'], 'only states a condition'
  end

  def test_verdicts_cached_under_earlier_rules_are_not_reused
    Dir.mktmpdir do |dir|
      args = { opening: 'A pull request keeps its decisions.', model: 'm', prompt: 'p', directory: dir }
      Shaka::OpeningVerdictCache.new(**args, rules: Shaka::OpeningVerdict::RULES_VERSION - 1)
                                .write({ 'status' => 'passed' })

      assert_nil Shaka::OpeningVerdictCache.new(**args).read
    end
  end

  private

  def verdict(character, action, hidden, reader_facing: true)
    Shaka::OpeningCheck.verdict([{ 'character' => character, 'reader_facing' => reader_facing,
                                   'character_can_act' => true, 'action' => action, 'object' => 'something',
                                   'hidden_actions' => hidden, 'internal_terms' => [] }])
  end
end
