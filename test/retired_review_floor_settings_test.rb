# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'

# Removed review floors must fail before a repository can use its merge policy.
class RetiredReviewFloorSettingsTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def load_with(merge: {}, description: nil)
    overrides = { 'merge' => merge_policy.merge(merge) }
    overrides['pr_description'] = description if description
    with_repository(overrides) { |root| yield Shaka::RepositoryConfig.load(root:) }
  end

  def test_a_retired_merge_floor_is_rejected_regardless_of_value
    replacements = %w[merge.auto_max_review_floor merge.auto_merge_max_risk high_risk_areas medium_risk_areas]
    [2, 5, 9, 'two', nil].each do |value|
      error = assert_raises(Shaka::Error) { load_with(merge: { 'auto_max_review_floor' => value }, &:to_h) }
      replacements.each do |setting|
        assert_includes error.message, setting
      end
    end
  end

  def test_retired_human_review_floors_are_rejected_regardless_of_value
    replacements = %w[pr_description.human_review_floors high_risk_areas medium_risk_areas]
    [[], nil, [{ 'level' => 5, 'reason' => 'docs', 'paths' => ['docs/**/*'] }]].each do |value|
      error = assert_raises(Shaka::Error) { load_with(description: { 'human_review_floors' => value }, &:to_h) }
      replacements.each do |setting|
        assert_includes error.message, setting
      end
    end
  end

  def test_a_configuration_without_them_keeps_the_risk_default
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
end
