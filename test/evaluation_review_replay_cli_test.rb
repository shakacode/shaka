# frozen_string_literal: true

require_relative 'test_helper'

class EvaluationReviewReplayCliTest < Minitest::Test
  CLI = File.expand_path('../eval/bin/review-replay', __dir__)

  def test_rejects_a_directory_as_the_installed_helper
    Dir.mktmpdir do |directory|
      _, error, status = Open3.capture3(RbConfig.ruby, CLI, '--helper', directory, '--state', directory,
                                        '--reviewer', 'openai/codex', '--criteria', 'a' * 40, '--baseline-model', 'a',
                                        '--candidate-model', 'b', '--budget', directory, '--pr', '1', '--cap', '1',
                                        '--case', 'unknown')

      refute_predicate status, :success?
      assert_includes error, 'Use the trusted installed Shaka helper'
      assert_empty Dir.children(directory)
    end
  end
end
