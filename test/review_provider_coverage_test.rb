# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'reviewer_command_fixture'
require 'shaka/reviewer_selection'
require 'shaka/review_coverage'
require 'shaka/repository_config'
require 'shaka/seam/field_classifier'

# review.provider_coverage names providers each PR should get a review from. Shaka reports a
# provider that did not review the commit as a gap with its reason; it never adds a reviewer or blocks.
class ReviewProviderCoverageTest < Minitest::Test
  include ReviewerCommandFixture

  CLAUDE = { 'provider' => 'anthropic', 'model_family' => 'claude' }.freeze
  CODEX = { 'provider' => 'openai', 'model_family' => 'codex' }.freeze
  PAIR = [CLAUDE, CODEX].freeze
  BOTH = %w[anthropic openai].freeze

  def test_no_coverage_setting_reports_no_gaps
    assert_empty gaps(['anthropic/claude'], coverage: [])
  end

  def test_two_reviewers_cover_both_providers
    assert_empty gaps(['anthropic/claude'], count: 2)
  end

  # Claude implements and Codex reviews; the hosted Claude review covers anthropic, which Ruby cannot see.
  def test_a_provider_beyond_the_count_is_a_gap
    assert_equal [gap('anthropic', Shaka::ReviewCoverage::NOT_CHOSEN)],
                 gaps(['anthropic/claude'])
  end

  # The author's own implementation is not a review of it.
  def test_the_implementing_provider_is_a_gap_when_it_does_not_review
    assert_equal [gap('openai', Shaka::ReviewCoverage::NOT_CHOSEN)],
                 gaps(['openai/codex'])
  end

  def test_a_missing_cli_and_an_unavailable_reviewer_name_their_reason
    not_set_up = gaps(['anthropic/claude'], count: 2, not_set_up: ['openai/codex'])
    unavailable = gaps(['anthropic/claude'], count: 2, unavailable: ['openai/codex'])

    assert_equal [gap('openai', Shaka::ReviewCoverage::NOT_SET_UP)], not_set_up
    assert_equal [gap('openai', Shaka::ReviewCoverage::UNAVAILABLE)], unavailable
  end

  def test_an_unlisted_provider_is_a_gap
    assert_equal [gap('openai', Shaka::ReviewCoverage::NOT_LISTED)], gaps(['anthropic/claude'], reviewers: [CLAUDE])
  end

  def test_provider_names_fold_case
    assert_empty gaps(['anthropic/claude'], count: 2, coverage: %w[Anthropic OPENAI])
  end

  def test_the_command_reads_coverage_from_the_seam
    with_repository do |root|
      set_review(root, 'provider_coverage' => BOTH)
      result = reviewer(root, '--implementer', 'anthropic/claude')

      assert_equal [gap('anthropic', Shaka::ReviewCoverage::NOT_CHOSEN)], result.fetch('coverage_gaps')
    end
  end

  def test_the_seam_rejects_malformed_coverage
    [['openai/codex'], 'openai', %w[openai OpenAI], [' openai']].each do |value|
      error = assert_raises(Shaka::Error, value.inspect) { validate('provider_coverage' => value) }

      assert_includes error.message, 'review.provider_coverage'
    end
  end

  def test_the_command_refuses_a_seam_with_malformed_coverage
    with_repository do |root|
      set_review(root, 'provider_coverage' => ['openai/codex'])
      _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root, '--implementer', 'anthropic/claude')

      refute_predicate status, :success?
      assert_includes error, 'review.provider_coverage must be a list of provider names'
    end
  end

  def test_migration_retains_coverage
    data = { 'version' => 1, 'merge' => { 'preference' => 'ask' },
             'review' => { 'required' => 'none', 'provider_coverage' => BOTH } }
    result = Shaka::Seam::FieldClassifier.new(data).call

    assert_empty result.blocking
    assert_equal BOTH, result.established.dig('review', 'provider_coverage')
  end

  private

  def gap(provider, reason) = { 'provider' => provider, 'reason' => reason }

  def validate(review) = Shaka::ReviewCoverage.validate!(review)

  def set_review(root, values)
    path = File.join(root, '.agents/agent-workflow.yml')
    settings = YAML.safe_load_file(path)
    settings['review'].merge!(values)
    File.write(path, YAML.dump(settings))
  end

  def gaps(implementers, coverage: BOTH, **options)
    parse = ->(list) { list.map { |text| Shaka::ReviewerSelection.parse(text) } }
    selection = Shaka::ReviewerSelection.new(
      reviewers: options.fetch(:reviewers, PAIR), implementers: parse.call(implementers),
      unavailable: parse.call(options.fetch(:unavailable, [])), not_set_up: parse.call(options.fetch(:not_set_up, [])),
      count: options.fetch(:count, 1)
    ).call
    Shaka::ReviewCoverage.gaps(coverage, selection)
  end
end
