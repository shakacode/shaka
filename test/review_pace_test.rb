# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'
require 'shaka/review_pace'

class ReviewPaceTest < Minitest::Test
  def test_omitted_pace_is_swift
    assert_equal 'swift', Shaka::ReviewPace.normalize(nil)
  end

  def test_rejects_an_unknown_pace
    error = assert_raises(Shaka::Error) { Shaka::ReviewPace.normalize('fast') }

    assert_includes error.message, 'review.pace must be swift or thorough'
  end

  def test_a_thorough_trusted_seam_cannot_be_weakened_to_swift
    assert_equal 'thorough', Shaka::ReviewPace.effective(seam: 'thorough', override: 'swift')
  end

  def test_a_this_task_override_can_raise_swift_to_thorough
    assert_equal 'thorough', Shaka::ReviewPace.effective(seam: 'swift', override: 'thorough')
  end

  def test_matching_seam_and_override_keep_swift
    assert_equal 'swift', Shaka::ReviewPace.effective(seam: nil, override: nil)
  end

  def test_thorough_merge_states_do_not_follow_the_default_constant
    assert_equal %w[CLEAN], Shaka::ReviewPace.allowed_merge_states('thorough', false)
    assert_includes Shaka::ReviewPace.allowed_merge_states('swift', false), 'UNSTABLE'
  end
end

class ReviewPaceSeamTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_defaults_omitted_review_pace_to_swift
    with_repository('review' => review_policy) do |root|
      config = Shaka::RepositoryConfig.load(root:)

      assert_equal 'swift', config.review.fetch('pace')
      assert_equal 'swift', config.to_h.dig('review', 'pace')
    end
  end

  def test_loads_an_explicit_thorough_review_pace
    with_repository('review' => review_policy('pace' => 'thorough')) do |root|
      assert_equal 'thorough', Shaka::RepositoryConfig.load(root:).review.fetch('pace')
    end
  end

  def test_rejects_an_unknown_review_pace
    with_repository('review' => review_policy('pace' => 'fast')) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.pace must be swift or thorough'
    end
  end

  def test_rejects_a_null_review_pace
    with_repository('review' => review_policy('pace' => nil)) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.pace must be swift or thorough'
    end
  end
end
