# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/publication/settings'
require 'shaka/review_coverage'

# https://github.com/shakacode/shaka/issues/887: the description compares the reviews that completed
# with the reviewers the trusted settings configure, so a reviewer that could not run stays visible.
class PublicationReviewerShortfallTest < Minitest::Test
  include EvidenceFixture

  COVERAGE = { 'provider_coverage' => %w[anthropic openai] }.freeze

  # A reviewer from a provider the setting does not list covers no listed one.
  def test_coverage_counts_only_the_listed_providers_that_reviewed
    assert_nil Shaka::ReviewCoverage.shortfall(COVERAGE, %w[openai/codex anthropic/claude])
    assert_equal shortfall(2, 1, ['anthropic']), Shaka::ReviewCoverage.shortfall(COVERAGE, %w[openai/codex xai/grok])
  end

  # A reviewer whose results were supplied twice still counts as one reviewer.
  def test_without_coverage_the_reviewer_count_is_compared
    count = { 'local_review_count' => 2 }

    assert_nil Shaka::ReviewCoverage.shortfall({}, ['openai/codex'])
    assert_equal shortfall(2, 1, []), Shaka::ReviewCoverage.shortfall(count, ['openai/codex'])
    assert_equal shortfall(2, 1, []), Shaka::ReviewCoverage.shortfall(count, %w[openai/codex OpenAI/Codex])
  end

  # The fixture's one bound review is a host-reported openai/codex review, which counts.
  def test_publication_compares_the_bound_reviews_with_the_trusted_settings
    assert_nil prepared_shortfall({})
    assert_equal shortfall(2, 1, []), prepared_shortfall({ 'local_review_count' => 2 })
    assert_equal shortfall(2, 1, ['anthropic']), prepared_shortfall(COVERAGE)
  end

  # https://github.com/shakacode/shaka/pull/955 passed only Codex's result after Claude reviewed the same
  # commit, and its description said Claude had not.
  def test_publication_refuses_results_that_leave_out_a_reviewer_of_the_same_batch
    rounds = [['anthropic/claude', :head, 'now'], ['openai/codex', :head, 'now']]
    error = assert_raises(Shaka::Error) { prepared_shortfall(COVERAGE, rounds:) }

    assert_includes error.message, 'anthropic/claude'
    assert_includes error.message, '`review check`'
    assert_nil prepared_shortfall(COVERAGE, rounds:, supplied: %w[openai/codex anthropic/claude])
  end

  # A lost result rebuilt with `review check` names no ledger round, yet still covers its reviewer.
  def test_publication_accepts_a_rebuilt_result_for_a_reviewer_of_the_batch
    rounds = [['anthropic/claude', :head, 'now'], ['openai/codex', :head, 'now']]

    assert_nil prepared_shortfall(COVERAGE, rounds:, supplied: %w[openai/codex anthropic/claude],
                                            rebuilt: ['anthropic/claude'])
  end

  # A review of another commit, or one under settings since replaced, belongs to another batch.
  def test_publication_keeps_the_gap_for_rounds_outside_the_supplied_batch
    rounds = [['anthropic/claude', 'b' * 40, 'now'], ['anthropic/claude', :head, 'before'],
              ['openai/codex', :head, 'now']]

    assert_equal shortfall(2, 1, ['anthropic']), prepared_shortfall(COVERAGE, rounds:)
  end

  private

  def shortfall(configured, completed, missing)
    { 'configured' => configured, 'completed' => completed, 'missing' => missing }
  end

  # Each round is [reviewer, head, settings]; a supplied reviewer's result names its round at :head
  # unless it was rebuilt.
  def prepared_shortfall(review, rounds: [], supplied: ['openai/codex'], rebuilt: [])
    with_checkout('review' => review_policy(review)) do |root, ref|
      Dir.mktmpdir do |directory|
        ledger = ledger_file(directory, rounds, ref)
        reviews = supplied.map { |reviewer| in_ledger(review_check(root, ref, reviewer:), ledger, ref, rebuilt) }
        with_results(directory, run_check(root, ref, command: 'validate'), reviews) do |options|
          return prepare(root, ref, options).reviewer_shortfall
        end
      end
    end
  end

  def prepare(root, ref, options)
    pull = { 'changed_files' => 0, 'head' => { 'sha' => ref }, 'base' => { 'sha' => ref } }
    Shaka::PublicationSettings.prepare(root:, ref:, pull:, options: options.merge(root:), github: empty_diff)
  end

  def ledger_file(directory, rounds, ref)
    path = File.join(directory, 'ledger.json')
    entries = rounds.map do |reviewer, head, settings|
      { 'head' => head == :head ? ref : head, 'reviewer' => reviewer, 'settings' => settings }
    end
    File.write(path, JSON.generate('version' => 3, 'rounds' => entries))
    path
  end

  def in_ledger(result, ledger, head, rebuilt)
    return result if rebuilt.include?(result['reviewer'])

    rounds = JSON.parse(File.read(ledger)).fetch('rounds')
    index = rounds.index { |round| round == { 'head' => head, 'reviewer' => result['reviewer'], 'settings' => 'now' } }
    index ? result.merge('ledger' => ledger, 'round' => index + 1) : result
  end

  def empty_diff
    Object.new.tap do |github|
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      def github.api_list(_path) = []
    end
  end

  def with_results(directory, validation, reviews)
    paths = [validation, *reviews].each_with_index.map do |result, index|
      File.join(directory, "result-#{index}.json").tap { |path| File.write(path, JSON.generate(result)) }
    end
    yield validation: paths.take(1), review: paths.drop(1)
  end
end
