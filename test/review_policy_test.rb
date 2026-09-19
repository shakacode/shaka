# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'

# The seam's ordered reviewer preference list and its identity requirements.
class ReviewPolicyTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_loads_the_reviewer_preference_list_in_order
    with_repository do |root|
      review = Shaka::RepositoryConfig.load(root:).review
      providers = review.fetch('reviewers').map { |entry| entry.fetch('provider') }

      assert_equal 'meaningful_changes', review.fetch('required')
      assert_equal %w[openai anthropic], providers
    end
  end

  def test_requires_each_reviewer_to_name_its_provider
    incomplete = [{ 'model_family' => 'claude' }]
    with_repository('review' => review_policy('reviewers' => incomplete)) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'missing review.reviewers[0] key: provider'
    end
  end

  def test_rejects_an_empty_reviewer_preference_list
    with_repository('review' => review_policy('reviewers' => [])) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.reviewers must not be empty'
    end
  end

  def test_rejects_a_repeated_reviewer_identity
    twice = reviewers + [reviewers.first]
    with_repository('review' => review_policy('reviewers' => twice)) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.reviewers repeats openai/codex'
    end
  end

  # Comparing joined strings would make "a b"/"c" and "a"/"b c" the same identity.
  def test_keeps_identities_whose_components_join_alike_distinct
    shifted = [{ 'provider' => 'a b', 'model_family' => 'c' },
               { 'provider' => 'a', 'model_family' => 'b c' }]
    with_repository('review' => review_policy('reviewers' => shifted)) do |root|
      review = Shaka::RepositoryConfig.load(root:).review
      providers = review.fetch('reviewers').map { |entry| entry.fetch('provider') }

      assert_equal ['a b', 'a'], providers
    end
  end

  def test_names_the_entry_behind_an_unknown_reviewer_key
    typo = [reviewers.first, { 'provider' => 'xai', 'model_family' => 'grok', 'draft' => false }]
    with_repository('review' => review_policy('reviewers' => typo)) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'unknown review.reviewers[1] key: draft'
    end
  end

  # `shaka reviewer` strips each component, so a padded value here would never match the
  # identity the agent passes and a contributing family could pass as eligible.
  def test_rejects_an_identity_component_padded_with_whitespace
    padded = [{ 'provider' => 'bedrock', 'model_family' => 'claude ' }]
    with_repository('review' => review_policy('reviewers' => padded)) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'model_family must not start or end with whitespace'
    end
  end

  def test_rejects_an_identity_component_containing_a_slash
    slashed = [{ 'provider' => 'openai/foo', 'model_family' => 'codex' }]
    with_repository('review' => review_policy('reviewers' => slashed)) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, "provider must not contain '/'"
    end
  end

  def test_points_a_retired_flat_field_at_the_reviewer_list
    retired = { 'required' => 'meaningful_changes', 'check' => 'claude-review',
                'model_family' => 'claude', 'provider' => 'anthropic', 'draft' => false }
    with_repository('review' => retired) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.model_family moved into review.reviewers'
    end
  end

  def test_keeps_reviewer_preferences_when_no_native_gate_is_required
    with_repository('review' => { 'required' => 'none', 'reviewers' => reviewers }) do |root|
      review = Shaka::RepositoryConfig.load(root:).review
      providers = review.fetch('reviewers').map { |entry| entry.fetch('provider') }

      assert_equal %w[openai anthropic], providers
    end
  end

  def test_rejects_a_named_check_when_review_is_not_required
    with_repository('review' => { 'required' => 'none', 'check' => 'claude-review' }) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.check must be omitted when review.required is none'
    end
  end

  def test_accepts_the_original_version_one_review_shape
    review = { 'required' => 'meaningful_changes', 'check' => 'claude-review' }
    with_repository('review' => review) do |root|
      assert_equal review, Shaka::RepositoryConfig.load(root:).review
    end
  end
end
