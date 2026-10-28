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

  def test_without_coverage_the_reviewer_count_is_compared
    assert_nil Shaka::ReviewCoverage.shortfall({}, ['openai/codex'])
    assert_equal shortfall(2, 1, []), Shaka::ReviewCoverage.shortfall({ 'local_review_count' => 2 }, ['openai/codex'])
  end

  # The fixture's one bound review is a host-reported openai/codex review, which counts.
  def test_publication_compares_the_bound_reviews_with_the_trusted_count
    assert_nil prepared_shortfall({})
    assert_equal shortfall(2, 1, []), prepared_shortfall('local_review_count' => 2)
  end

  private

  def shortfall(configured, completed, missing)
    { 'configured' => configured, 'completed' => completed, 'missing' => missing }
  end

  def prepared_shortfall(review)
    with_checkout('review' => review_policy(review)) do |root, ref|
      with_results(run_check(root, ref, command: 'validate'), review_check(root, ref)) do |options|
        pull = { 'changed_files' => 0, 'head' => { 'sha' => ref }, 'base' => { 'sha' => ref } }
        return Shaka::PublicationSettings.prepare(root:, ref:, pull:, options: options.merge(root:),
                                                  github: empty_diff).reviewer_shortfall
      end
    end
  end

  def empty_diff
    Object.new.tap do |github|
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      def github.api_list(_path) = []
    end
  end

  def with_results(validation, review)
    Tempfile.create(['validation-', '.json']) do |first|
      Tempfile.create(['review-', '.json']) do |second|
        first.write(JSON.generate(validation))
        second.write(JSON.generate(review))
        first.flush
        second.flush
        yield validation: [first.path], review: [second.path]
      end
    end
  end
end
