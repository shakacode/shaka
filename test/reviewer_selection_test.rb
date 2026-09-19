# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/reviewer_selection'

# Selection is the alternate-review gate, so these cases are the gate's behavior.
class ReviewerSelectionTest < Minitest::Test
  ROSTER = [{ 'provider' => 'anthropic', 'model_family' => 'claude' },
            { 'provider' => 'openai', 'model_family' => 'codex' },
            { 'provider' => 'xai', 'model_family' => 'grok' }].freeze

  def select(implementers, unavailable: [], reviewers: ROSTER)
    Shaka::ReviewerSelection.new(
      reviewers:,
      implementers: implementers.map { |text| Shaka::ReviewerSelection.parse(text) },
      unavailable: unavailable.map { |text| Shaka::ReviewerSelection.parse(text) }
    ).call
  end

  def test_takes_the_first_entry_differing_in_provider_and_family
    result = select(['anthropic/claude'])

    assert_equal 'alternate', result.fetch('outcome')
    assert_equal 'openai/codex', result.fetch('reviewer')
  end

  def test_skips_an_unavailable_entry_for_the_next_provider
    result = select(['anthropic/claude'], unavailable: ['openai/codex'])

    assert_equal 'alternate', result.fetch('outcome')
    assert_equal 'xai/grok', result.fetch('reviewer')
  end

  # The implementation model family reached through another provider is still same-model review.
  def test_rejects_the_implementation_family_under_another_provider
    roster = [{ 'provider' => 'bedrock', 'model_family' => 'claude' },
              { 'provider' => 'openai', 'model_family' => 'codex' }]
    result = select(['anthropic/claude'], reviewers: roster)

    assert_equal 'openai/codex', result.fetch('reviewer')
    assert_includes result.fetch('considered').first.fetch('reason'), 'model family contributed'
  end

  # A provider compared against the family set would wrongly accept openai/gpt here.
  def test_rejects_a_sibling_family_from_a_contributing_provider_as_the_alternate
    roster = [{ 'provider' => 'openai', 'model_family' => 'gpt' },
              { 'provider' => 'anthropic', 'model_family' => 'claude' }]
    result = select(['openai/codex'], reviewers: roster)

    assert_equal 'alternate', result.fetch('outcome')
    assert_equal 'anthropic/claude', result.fetch('reviewer')
  end

  def test_uses_the_same_provider_floor_when_no_other_provider_qualifies
    roster = [{ 'provider' => 'openai', 'model_family' => 'gpt' }]
    result = select(['openai/codex'], reviewers: roster)

    assert_equal 'same_provider', result.fetch('outcome')
    assert_equal 'openai/gpt', result.fetch('reviewer')
    assert_includes result.fetch('note'), 'label the review same-provider'
  end

  # A delegated worker's model contributed, so a reviewer matching it would self-review.
  def test_excludes_every_contributing_family_not_only_the_owner
    result = select(['anthropic/claude', 'openai/codex'])

    assert_equal 'xai/grok', result.fetch('reviewer')
  end

  def test_reports_an_outside_reviewer_when_no_entry_qualifies
    result = select(['anthropic/claude', 'openai/codex', 'xai/grok'])

    assert_equal 'outside_list', result.fetch('outcome')
    assert_nil result.fetch('reviewer')
    assert_includes result.fetch('note'), 'outside the list'
  end

  def test_reports_an_outside_reviewer_when_every_qualifying_entry_is_unavailable
    result = select(['anthropic/claude'], unavailable: %w[openai/codex xai/grok])

    assert_equal 'outside_list', result.fetch('outcome')
  end

  def test_reports_an_outside_reviewer_when_the_seam_declares_no_list
    result = select(['anthropic/claude'], reviewers: nil)

    assert_equal 'outside_list', result.fetch('outcome')
  end

  def test_names_both_contributing_sets_separately
    result = select(['anthropic/claude', 'openai/codex'])

    assert_equal %w[anthropic openai], result.fetch('contributing_providers')
    assert_equal %w[claude codex], result.fetch('contributing_families')
  end

  # An identity read from display metadata may be cased differently than the seam spells it.
  def test_excludes_a_contributing_family_spelled_with_different_casing
    result = select(['OpenAI/Codex'])

    assert_equal 'anthropic/claude', result.fetch('reviewer')
  end

  def test_matches_an_unavailable_identity_regardless_of_casing
    result = select(['anthropic/claude'], unavailable: ['OpenAI/Codex'])

    assert_equal 'xai/grok', result.fetch('reviewer')
  end

  # The audit trail should name the permanent disqualification, not this attempt's state.
  def test_reports_a_contributing_family_ahead_of_unavailability
    result = select(['anthropic/claude'], unavailable: ['anthropic/claude'])
    claude = result.fetch('considered').find { |row| row.fetch('reviewer') == 'anthropic/claude' }

    assert_equal 'model family contributed', claude.fetch('reason')
  end

  # An unavailable same-provider entry must still not be chosen as the floor.
  def test_does_not_use_an_unavailable_entry_as_the_same_provider_floor
    roster = [{ 'provider' => 'openai', 'model_family' => 'gpt' }]
    result = select(['openai/codex'], unavailable: ['openai/gpt'], reviewers: roster)

    assert_equal 'outside_list', result.fetch('outcome')
  end

  # Joined-string keys would make "openai/foo"/"codex" and "openai"/"foo/codex" one identity.
  def test_distinguishes_entries_whose_joined_identity_matches
    roster = [{ 'provider' => 'openai/foo', 'model_family' => 'codex' },
              { 'provider' => 'anthropic', 'model_family' => 'claude' }]
    result = Shaka::ReviewerSelection.new(
      reviewers: roster,
      implementers: [{ 'provider' => 'openai', 'model_family' => 'foo/codex' }]
    ).call

    assert_equal 'alternate', result.fetch('outcome')
    assert_equal 'openai/foo/codex', result.fetch('reviewer')
  end

  # split('/') drops trailing empties, so a stray slash would have validated.
  def test_rejects_an_identity_with_a_stray_slash
    ['openai/gpt/', 'openai/', '/gpt'].each do |text|
      error = assert_raises(Shaka::Error) { Shaka::ReviewerSelection.parse(text) }

      assert_includes error.message, 'PROVIDER/MODEL_FAMILY'
    end
  end

  def test_rejects_an_identity_without_a_model_family
    error = assert_raises(Shaka::Error) { Shaka::ReviewerSelection.parse('anthropic') }

    assert_includes error.message, 'PROVIDER/MODEL_FAMILY'
  end

  def test_requires_at_least_one_implementer
    error = assert_raises(Shaka::Error) { select([]) }

    assert_includes error.message, 'implementer identity is required'
  end
end
