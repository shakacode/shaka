# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require_relative 'repository_fixture'

# With review.provider_coverage, readiness checks each covered provider by name, not a count.
class DoctorCoverageTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers

  # Codex and Grok cover two providers, but neither is the covered anthropic.
  def test_a_covered_provider_without_an_installed_reviewer_warns
    grok = { 'provider' => 'xai', 'model_family' => 'grok', 'model' => 'grok-4.7' }
    review = review_policy('provider_coverage' => %w[anthropic openai], 'local_review_agents' => [agents.first, grok])
    with_repository('review' => review) do |root|
      report, blocked = doctor(root:, executable: ->(*) { true })

      assert_includes report, '[DEGRADED] Reviewer CLIs'
      assert_includes report, 'No configured reviewer is installed for covered provider anthropic.'
      refute blocked
    end
  end

  def test_covered_providers_with_installed_reviewers_are_healthy
    review = review_policy('provider_coverage' => %w[anthropic openai], 'local_review_agents' => agents)
    with_repository('review' => review) do |root|
      report, = doctor(root:, executable: ->(*) { true })

      assert_includes report, '[HEALTHY] Reviewer CLIs'
    end
  end

  # Break caught: with no reviewers configured, readiness returned before checking coverage.
  def test_coverage_without_configured_reviewers_warns_for_each_provider
    review = review_policy('provider_coverage' => %w[anthropic openai]).except('local_review_agents')
    with_repository('review' => review) do |root|
      report, = doctor(root:, executable: ->(*) { true })

      assert_includes report, 'No configured reviewer is installed for covered provider anthropic.'
      assert_includes report, 'No configured reviewer is installed for covered provider openai.'
    end
  end

  # Coverage never selects DeepSeek here, so its missing key changes nothing that runs.
  def test_an_uncovered_reviewer_without_setup_keeps_doctor_healthy
    review = review_policy('provider_coverage' => %w[anthropic openai], 'local_review_agents' => agents + [deepseek])
    with_repository('review' => review) do |root|
      report, = doctor(root:, executable: ->(*) { true }, environment: {})

      assert_includes report, '[HEALTHY] Reviewer CLIs'
      assert_includes report, 'OPENROUTER_API_KEY missing (optional: runs only when a task names it)'
      refute_includes report, 'local setup is incomplete'
    end
  end

  # Only uncovered entries go quiet: a covered reviewer selection would pick still warns.
  def test_coverage_still_warns_about_a_covered_reviewer_without_setup
    review = review_policy('provider_coverage' => %w[anthropic openai], 'local_review_agents' => agents + [deepseek])
    with_repository('review' => review) do |root|
      report, = doctor(root:, executable: ->(name, *) { name != 'codex' }, environment: {})

      assert_includes report, '[DEGRADED] Reviewer CLIs'
      assert_includes report, 'This repository configures openai/codex reviews, but local setup is incomplete.'
      refute_includes report, 'This repository configures deepseek/openrouter reviews'
    end
  end

  # Without coverage, any listed reviewer can be a fallback, so its missing setup still warns.
  def test_without_coverage_a_reviewer_without_setup_still_warns
    review = review_policy('local_review_agents' => agents + [deepseek])
    with_repository('review' => review) do |root|
      report, = doctor(root:, executable: ->(*) { true }, environment: {})

      assert_includes report, '[DEGRADED] Reviewer CLIs'
      assert_includes report, 'This repository configures deepseek/openrouter reviews, but local setup is incomplete.'
    end
  end

  private

  def deepseek = { 'provider' => 'deepseek', 'model_family' => 'openrouter', 'model' => 'deepseek/deepseek-v4.1-flash' }

  def agents
    [{ 'provider' => 'openai', 'model_family' => 'codex' },
     { 'provider' => 'anthropic', 'model_family' => 'claude' }]
  end
end
