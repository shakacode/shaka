# frozen_string_literal: true

require_relative 'test_helper'

class EvaluationReviewReplayCliTest < Minitest::Test
  CLI = File.expand_path('../eval/bin/review-replay', __dir__)
  BANKS = File.expand_path('../eval/review-replay', __dir__)

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

  def test_rejects_an_unknown_case_bank_before_building_fixtures
    Dir.mktmpdir do |directory|
      helper = File.join(directory, 'shaka')
      File.write(helper, "#!/bin/sh\n")
      File.chmod(0o700, helper)
      _, error, status = Open3.capture3(RbConfig.ruby, CLI, '--helper', helper, '--state', directory,
                                        '--reviewer', 'openai/codex', '--criteria', 'a' * 40, '--baseline-model', 'a',
                                        '--candidate-model', 'b', '--bank', '../v1', '--preview')

      refute_predicate status, :success?
      assert_includes error, 'Unknown replay bank'
      assert_equal ['shaka'], Dir.children(directory)
    end
  end

  def test_each_bank_keeps_the_frozen_cases_of_the_one_before
    banks = Dir[File.join(BANKS, 'v*.jsonl')].sort_by { |path| File.basename(path)[/\d+/].to_i }
    rows = banks.map { |path| File.readlines(path, chomp: true) }

    rows.each_cons(2) { |older, newer| assert_equal older, newer.first(older.size) }
    rows.flatten.map { |line| JSON.parse(line) }.each do |row|
      assert_match(/\A[0-9a-f]{40}\z/, row.fetch('base'))
      assert_match(/\A[0-9a-f]{40}\z/, row.fetch('head'))
    end
    assert_equal rows.last.size, rows.last.map { |line| JSON.parse(line).fetch('id') }.uniq.size
  end
end
