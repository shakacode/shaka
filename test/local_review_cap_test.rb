# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'seam_check_helpers'

class LocalReviewCapSettingTest < Minitest::Test
  include SeamCheckHelpers

  def test_seam_defaults_to_five_rounds
    with_repository do |root|
      commit_repository(root)
      assert_equal 5, check_config(root, '--ref', 'HEAD').dig('review', 'local_max_rounds')
    end
  end

  def test_seam_accepts_a_positive_integer_from_trusted_policy
    with_repository do |root|
      write_cap(root, 2)
      commit_repository(root)
      write_cap(root, 99)
      assert_equal 2, check_config(root, '--ref', 'HEAD').dig('review', 'local_max_rounds')
    end
  end

  def test_seam_refuses_non_positive_or_non_integer_caps
    [0, -1, 1.5, '5', true, nil].each do |cap|
      with_repository do |root|
        path = File.join(root, '.agents/agent-workflow.yml')
        File.write(path, YAML.dump(config.merge('review' => config['review'].merge('local_max_rounds' => cap))))
        commit_repository(root)
        _output, error, status = capture_check(root, '--ref', 'HEAD')
        refute_predicate status, :success?
        assert_includes error, 'review.local_max_rounds must be a positive integer'
      end
    end
  end

  private

  def write_cap(root, cap)
    path = File.join(root, '.agents/agent-workflow.yml')
    File.write(path, YAML.dump(config.merge('review' => config['review'].merge('local_max_rounds' => cap))))
  end
end
