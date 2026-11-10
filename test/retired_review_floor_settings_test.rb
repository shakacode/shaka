# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'

# The 1-5 review floors are retired. For one release a repository that still sets them loads, says so in its
# warnings, and gets the risk rating's defaults; the next release refuses them.
class RetiredReviewFloorSettingsTest < Minitest::Test
  include RepositoryConfigTestHelpers

  FLOORS = [{ 'level' => 5, 'reason' => 'changes docs', 'paths' => ['docs/**/*'] }].freeze

  def load_with(merge: {}, description: nil)
    overrides = { 'merge' => merge_policy.merge(merge) }
    overrides['pr_description'] = description if description
    with_repository(overrides) { |root| yield Shaka::RepositoryConfig.load(root:) }
  end

  def test_a_retired_merge_floor_warns_and_is_ignored
    load_with(merge: { 'auto_max_review_floor' => 2 }) do |config|
      refute config.merge.key?('auto_max_review_floor')
      assert_equal 'low', config.merge.fetch('auto_merge_max_risk')
      assert_equal '2', config.retired_floor
      assert_includes config.warnings.join, 'Below 5 it holds every agent merge until removed'
    end
  end

  # Even a value the old schema refused loads, because nothing reads it any more.
  def test_any_retired_floor_value_loads
    [9, 'two', nil].each do |value|
      load_with(merge: { 'auto_max_review_floor' => value }) do |config|
        assert_equal 1, config.warnings.grep(/\Amerge\.auto_max_review_floor/).size
      end
    end
  end

  def test_retired_human_review_floors_warn_and_are_ignored
    load_with(description: { 'human_review_floors' => FLOORS }) do |config|
      refute config.pr_description.key?('human_review_floors')
      refute config.to_h.fetch('pr_description').key?('human_review_floors')
      assert_includes config.warnings,
                      'pr_description.human_review_floors is retired and ignored; list paths that must reach a ' \
                      'person under high_risk_areas. Remove it; the next release refuses it.'
    end
  end

  def test_a_configuration_without_them_has_no_retirement_warning
    load_with do |config|
      assert_empty config.warnings.grep(/retired/)
      assert_equal 'low', config.merge.fetch('auto_merge_max_risk')
    end
  end

  def test_an_explicit_risk_level_wins_over_the_default
    load_with(merge: { 'auto_merge_max_risk' => 'medium' }) do |config|
      assert_equal 'medium', config.merge.fetch('auto_merge_max_risk')
    end
  end

  # The top level held nothing, so a repository that still states it is not held.
  def test_a_retired_floor_of_five_holds_nothing
    load_with(merge: { 'auto_max_review_floor' => 5 }) { |config| assert_nil config.retired_floor }
    load_with { |config| assert_nil config.retired_floor }
  end
end
