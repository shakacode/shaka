# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'reviewer_command_fixture'
require 'shaka/reviewer_selection'

# Running several local reviewers on one head, so every finding lands in one repair batch.
class ReviewerCountTest < Minitest::Test
  include ReviewerCommandFixture

  ROSTER = [{ 'provider' => 'anthropic', 'model_family' => 'claude' },
            { 'provider' => 'openai', 'model_family' => 'codex' },
            { 'provider' => 'xai', 'model_family' => 'grok' }].freeze

  def test_lists_the_single_reviewer_by_default
    assert_equal [%w[openai/codex different_provider]], run_order(select(['anthropic/claude']))
  end

  # Claude implements; Codex and a fresh Claude both review the same head.
  def test_fills_later_slots_in_list_order_after_one_different_provider
    result = select(['anthropic/claude'], count: 2)

    assert_equal 'openai/codex', result.fetch('reviewer')
    assert_equal [%w[openai/codex different_provider], %w[anthropic/claude same_provider]], run_order(result)
  end

  def test_skips_unavailable_entries_when_filling_slots
    result = select(['anthropic/claude'], unavailable: ['anthropic/claude'], count: 2)

    assert_equal [%w[openai/codex different_provider], %w[xai/grok different_provider]], run_order(result)
  end

  def test_runs_only_the_available_reviewers_when_fewer_than_requested
    result = select(['anthropic/claude'], unavailable: %w[openai/codex xai/grok], count: 3)

    assert_equal [%w[anthropic/claude same_provider]], run_order(result)
  end

  def test_same_model_fallback_is_the_only_reviewer
    assert_equal [%w[openai/codex same_model]], run_order(select(['openai/codex'], reviewers: nil, count: 2))
  end

  def test_requires_a_positive_count
    error = assert_raises(Shaka::Error) { select(['anthropic/claude'], count: 0) }

    assert_includes error.message, 'at least 1'
  end

  def test_command_selects_several_reviewers
    with_repository do |root|
      result = reviewer(root, '--implementer', 'anthropic/claude', '--count', '2')

      assert_equal(%w[openai/codex anthropic/claude], result.fetch('reviewers').map { |row| row.fetch('reviewer') })
    end
  end

  def test_command_rejects_a_count_that_is_not_an_integer
    with_repository do |root|
      _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root,
                                        '--implementer', 'anthropic/claude', '--count', 'two')

      refute_predicate status, :success?
      assert_includes error, '--count'
    end
  end

  private

  def select(implementers, unavailable: [], reviewers: ROSTER, count: 1)
    Shaka::ReviewerSelection.new(
      reviewers:,
      implementers: implementers.map { |text| Shaka::ReviewerSelection.parse(text) },
      unavailable: unavailable.map { |text| Shaka::ReviewerSelection.parse(text) },
      count:
    ).call
  end

  def run_order(result) = result.fetch('reviewers').map { |row| row.values_at('reviewer', 'outcome') }
end
