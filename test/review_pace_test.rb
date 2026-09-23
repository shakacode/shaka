# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'yaml'
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

  def test_explicit_swift_stays_swift_even_if_the_product_default_changes
    original = Shaka::ReviewPace::DEFAULT
    Shaka::ReviewPace.send(:remove_const, :DEFAULT)
    Shaka::ReviewPace.const_set(:DEFAULT, 'thorough')

    assert_equal 'swift', Shaka::ReviewPace.effective(seam: 'swift', override: nil)
  ensure
    Shaka::ReviewPace.send(:remove_const, :DEFAULT)
    Shaka::ReviewPace.const_set(:DEFAULT, original)
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

      refute config.review.fetch('wait_for_all_ci_reviewers')
      refute config.to_h.fetch('review').fetch('wait_for_all_ci_reviewers')
    end
  end

  def test_loads_an_explicit_thorough_review_pace
    with_repository('review' => review_policy('wait_for_all_ci_reviewers' => true)) do |root|
      assert Shaka::RepositoryConfig.load(root:).review.fetch('wait_for_all_ci_reviewers')
    end
  end

  def test_rejects_an_unknown_review_pace
    with_repository('review' => review_policy('wait_for_all_ci_reviewers' => 'false')) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.wait_for_all_ci_reviewers must be true or false'
    end
  end

  def test_rejects_a_null_review_pace
    with_repository('review' => review_policy('wait_for_all_ci_reviewers' => nil)) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.wait_for_all_ci_reviewers must be true or false'
    end
  end

  def test_reads_thorough_pace_from_a_trusted_ref_not_the_candidate_file
    with_repository('review' => review_policy('wait_for_all_ci_reviewers' => true)) do |root|
      commit_repository(root)
      weaken_candidate_pace(root)

      assert_equal 'thorough', Shaka::ReviewPace.seam_from_ref(root:, ref: 'HEAD')
      assert_nil Shaka::ReviewPace.seam_from_ref(root:, ref: nil)
    end
  end

  def test_legacy_key_requires_migration
    with_repository('review' => review_policy('pace' => 'thorough')) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'review.wait_for_all_ci_reviewers'
    end
  end

  def commit_repository(root)
    system('git', '-C', root, 'init', '--quiet', exception: true)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '--quiet', '-m', 'trusted', exception: true)
  end

  def weaken_candidate_pace(root)
    path = File.join(root, '.agents/agent-workflow.yml')
    data = YAML.load_file(path)
    data['review']['wait_for_all_ci_reviewers'] = false
    File.write(path, YAML.dump(data))
  end
end
