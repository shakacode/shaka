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
    %w[../v1 v99].each do |bank|
      error, status = preview('--bank', bank)

      refute_predicate status, :success?
      assert_includes error, 'Unknown replay bank'
    end
  end

  # r05 is only in v2, so the default selects it while v1 refuses it. Building its fixture needs the fetched PR refs.
  def test_replays_v2_by_default_and_v1_on_request
    default_error, = preview('--case', 'r05')
    v1_error, v1_status = preview('--case', 'r05', '--bank', 'v1')

    refute_includes default_error, 'Unknown replay'
    refute_predicate v1_status, :success?
    assert_includes v1_error, 'Unknown replay case'
  end

  def test_each_bank_keeps_the_frozen_cases_of_the_one_before
    names = banks.map { |path| File.basename(path, '.jsonl') }
    rows = banks.map { |path| File.readlines(path, chomp: true) }

    assert_equal %w[v1 v2], names.first(2)
    rows.each_cons(2) { |older, newer| assert_equal older, newer.first(older.size) }
  end

  def test_the_newest_bank_pins_unique_cases_to_full_commits
    rows = File.foreach(banks.last).map { |line| JSON.parse(line) }

    assert_equal rows.size, rows.map { |row| row.fetch('id') }.uniq.size
    rows.flat_map { |row| row.values_at('base', 'head') }.each { |sha| assert_match(/\A[0-9a-f]{40}\z/, sha) }
  end

  private

  def banks = Dir[File.join(BANKS, 'v*.jsonl')].sort_by { |path| File.basename(path)[/\d+/].to_i }

  def preview(*)
    Dir.mktmpdir do |directory|
      helper = File.join(directory, 'shaka')
      File.write(helper, "#!/bin/sh\n")
      File.chmod(0o700, helper)
      _, error, status = Open3.capture3(RbConfig.ruby, CLI, '--helper', helper, '--state', directory,
                                        '--reviewer', 'openai/codex', '--criteria', 'a' * 40, '--baseline-model', 'a',
                                        '--candidate-model', 'b', '--preview', *)
      [error, status]
    end
  end
end
