# frozen_string_literal: true

require_relative 'test_helper'
require 'digest'
require 'fileutils'
require_relative '../skills/shaka/lib/shaka/opening_check'
require_relative 'opening_check_test_helpers'

# A first sentence that only states a condition hides the change; the verdict flags it from the parse alone.
class OpeningStateVerbTest < Minitest::Test
  include OpeningCheckTestHelpers

  OPENING = 'A pull request keeps its open decisions when its body has a line starting with inline code.'

  def test_flags_a_state_verb_that_hides_actions
    # The shape a model returned for the opening of #1331.
    result = verdict('keeps', ['deciding'])

    assert_equal 'flagged', result['status']
    refute result['terms_only']
    assert_includes result['reason'], '"keeps"'
  end

  def test_flags_a_state_verb_without_a_change_marker
    ['still has', 'Remains', 'automatically retains'].each do |action|
      assert_equal 'flagged', verdict(action, ['publishing'])['status'], action
    end
  end

  def test_passes_a_state_verb_that_says_what_changed
    ['now retains', 'no longer keeps', 'has again', 'starts to retain', "doesn't keep"].each do |action|
      assert_equal 'passed', verdict(action, ['approval'])['status'], action
    end
  end

  def test_passes_a_state_verb_with_no_hidden_actions
    assert_equal 'passed', verdict('keeps', [])['status']
  end

  def test_passes_an_event_verb_with_hidden_actions
    ['no longer deletes', 'has stopped deleting', 'is marked', 'keeps publishing'].each do |action|
      assert_equal 'passed', verdict(action, ['republishing'])['status'], action
    end
  end

  def test_earlier_first_sentence_rules_are_reported_first
    internal = verdict('keeps', ['deciding'], reader_facing: false)['reason']
    person_verb = verdict('keeps', ['deciding'], character_can_act: false)['reason']

    assert_includes internal, 'is not something a maintainer cares about'
    assert_includes person_verb, 'an action it cannot perform'
    [internal, person_verb].each { refute_includes it, 'states a condition' }
  end

  def test_a_pass_cached_under_the_earlier_rules_is_checked_again
    parse = { sentences: [sentence('keeps', ['deciding'], reader_facing: true, character_can_act: true)] }
    with_claude(parse) do |root, trace|
      seed_earlier_rules_pass(root)

      assert_equal 'flagged', check(OPENING, root:)['status']
      assert_path_exists trace, 'the model must parse the opening again'
    end
  end

  private

  def verdict(action, hidden, reader_facing: true, character_can_act: true)
    Shaka::OpeningCheck.verdict([sentence(action, hidden, reader_facing:, character_can_act:)])
  end

  def sentence(action, hidden, reader_facing:, character_can_act:)
    { 'character' => 'A pull request', 'reader_facing' => reader_facing, 'character_can_act' => character_can_act,
      'action' => action, 'object' => 'something', 'hidden_actions' => hidden, 'internal_terms' => [] }
  end

  # Writes the cache entry the rules before version 2 left, keyed without a rules version.
  def seed_earlier_rules_pass(root)
    prompt = Shaka::OpeningCheck.new(summary: OPENING, candidate_root: root).send(:model_prompt)
    directory = File.join(File.dirname(root), 'cache')
    FileUtils.mkdir_p(directory)
    key = Digest::SHA256.hexdigest(['anthropic/claude//low', prompt, OPENING].join("\0"))
    File.write(File.join(directory, key), 'passed')
  end
end
