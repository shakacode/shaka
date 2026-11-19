# frozen_string_literal: true

require_relative 'test_helper'

class LocalReviewHelpTest < Minitest::Test
  def test_help_explains_settings_dependencies
    %w[run check].each do |action|
      output, error, status = Open3.capture3(*SHAKA_COMMAND, 'review', action, '--help')
      assert_predicate status, :success?, error
      assert_match(/--settings-ref requires --repository and --root/, output)
    end
  end

  def test_missing_settings_dependencies_point_to_usage_before_launch
    combinations = [[], ['--repository', 'o/r']]
    %w[run check].each do |action|
      combinations.each do |arguments|
        _output, error, status = Open3.capture3(*SHAKA_COMMAND, 'review', action,
                                                '--settings-ref', 'a' * 40, *arguments)
        refute_predicate status, :success?
        assert_includes error, "review #{action} --help"
        assert_includes error, arguments.empty? ? '--repository is required' : '--root is required'
      end
    end
  end
end
