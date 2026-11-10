# frozen_string_literal: true

require_relative 'local_review_test'

# Break caught: a reviewer launch the shell mangled printed only a stderr line, so a caller
# waiting on the JSON result read an empty file and took the reviewer for still running.
class LocalReviewArgumentErrorTest < Minitest::Test
  COMMAND = LocalReviewCodexTest::COMMAND
  include LocalReviewFixture

  # zsh does not split an unquoted variable, so `e="--effort medium"; ... $e` passes one word.
  def test_option_and_value_passed_as_one_word_return_a_setup_failure
    assert_unlaunched('--effort medium', 'invalid option: --effort medium')
  end

  # bash keeps an empty quoted variable, so `"$e"` passes an empty argument.
  def test_stray_empty_argument_returns_a_setup_failure
    assert_unlaunched('', 'unexpected argument ""')
  end

  private

  def assert_unlaunched(extra, reason)
    with_repository do |root, base, head, bin|
      trace = File.join(bin, 'launched')
      write_executable(bin, 'codex', "#!/bin/sh\ntouch #{trace}\n")
      output, _error, status = Open3.capture3({ 'PATH' => "#{bin}:#{ENV.fetch('PATH')}" },
                                              *review_arguments(root, base, head, 'openai/codex', {}), extra)
      refute_predicate status, :success?
      assert_not_completed(JSON.parse(output), head, reason)
      refute_path_exists trace
    end
  end

  def assert_not_completed(result, head, reason)
    assert_equal %w[not_completed setup_failure not_eligible],
                 result.values_at('status', 'failure_stage', 'skip_evidence')
    assert_equal [head, 'openai/codex', false], result.values_at('head', 'reviewer', 'attempted')
    assert_includes result.fetch('reason'), reason
  end
end
