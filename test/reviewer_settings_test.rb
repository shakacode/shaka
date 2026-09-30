# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require_relative 'repository_fixture'
require 'shaka/reviewer_settings'

class ReviewerSettingsTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers

  def notices(identity, model: nil, effort: nil)
    Shaka::ReviewerSettings.notices(identity, model:, effort:)
  end

  def test_a_blank_model_and_effort_need_no_notice
    assert_empty notices('openai/codex')
  end

  def test_a_one_character_model_typo_names_the_known_model
    notice = notices('openai/codex', model: 'gpt-6-sll').fetch(0)

    assert_equal 'degraded', notice.fetch('severity')
    assert_includes notice.fetch('summary'), 'gpt-6-sll'
    assert_includes notice.fetch('summary'), 'gpt-6-sol'
  end

  def test_a_one_digit_model_change_is_not_called_a_typo
    notice = notices('xai/grok', model: 'grok-4.8').fetch(0)

    assert_equal 'degraded', notice.fetch('severity')
    assert_includes notice.fetch('summary'), 'not a model Shaka knows'
    refute_includes notice.fetch('summary'), 'typo'
  end

  def test_a_transposed_effort_names_the_known_level
    notice = notices('openai/codex', effort: 'meduim').fetch(0)

    assert_equal 'degraded', notice.fetch('severity')
    assert_includes notice.fetch('summary'), 'meduim'
    assert_includes notice.fetch('summary'), 'medium'
  end

  def test_a_claude_effort_outside_the_help_list_fails
    notice = notices('anthropic/claude', effort: 'turbo').fetch(0)

    assert_equal 'failed', notice.fetch('severity')
    assert_includes notice.fetch('summary'), 'turbo'
    assert_includes notice.fetch('summary'), 'max'
  end

  def test_a_claude_effort_one_character_off_still_fails
    notice = notices('anthropic/claude', effort: 'meduim').fetch(0)

    assert_equal 'failed', notice.fetch('severity')
    assert_includes notice.fetch('summary'), 'medium'
    assert_includes notice.fetch('summary'), 'not one of'
  end

  def test_an_unknown_model_warns_and_names_the_recommendation
    notice = notices('openai/codex', model: 'gpt-9-nova').fetch(0)

    assert_equal 'degraded', notice.fetch('severity')
    assert_includes notice.fetch('summary'), 'gpt-9-nova'
    assert_includes notice.fetch('summary'), 'gpt-6-sol'
  end

  def test_a_known_model_other_than_the_recommendation_is_a_warning
    notice = notices('openai/codex', model: 'gpt-6-astra').fetch(0)

    assert_equal 'degraded', notice.fetch('severity')
    assert_includes notice.fetch('summary'), 'gpt-6-astra'
    assert_includes notice.fetch('summary'), 'gpt-6-sol'
  end

  def test_the_recommended_model_and_a_listed_effort_are_quiet
    assert_empty notices('openai/codex', model: 'gpt-6-sol', effort: 'medium')
    assert_empty notices('anthropic/claude', model: 'claude-opus-5-5', effort: 'max')
  end

  def test_doctor_warns_about_a_misspelled_model
    agents = [{ 'provider' => 'openai', 'model_family' => 'codex', 'model' => 'gpt-6-sll', 'effort' => 'medium' }]
    report, blocked = doctor_for(agents)

    assert_includes report, '[DEGRADED] Reviewer settings'
    assert_includes report, 'looks like a typo of `gpt-6-sol`'
    refute blocked
  end

  def test_doctor_fails_a_claude_effort_outside_the_list
    agents = [{ 'provider' => 'anthropic', 'model_family' => 'claude', 'effort' => 'turbo' }]
    report, blocked = doctor_for(agents)

    assert_includes report, '[FAILED] Reviewer settings'
    assert_includes report, 'turbo'
    assert blocked
  end

  def test_an_unreadable_seam_still_reports_every_check
    with_repository do |root|
      File.chmod(0o000, File.join(root, '.agents/agent-workflow.yml'))
      report, blocked = doctor(root:)

      assert_includes report, '[DEGRADED] Reviewer settings'
      assert_includes report, 'repository seam is not healthy'
      assert_includes report, 'Machine alias'
      assert blocked
    end
  end

  def test_doctor_warns_when_a_known_model_is_not_the_recommendation
    agents = [{ 'provider' => 'openai', 'model_family' => 'codex', 'model' => 'gpt-6-astra' }]
    report, blocked = doctor_for(agents)

    assert_includes report, '[DEGRADED] Reviewer settings'
    assert_includes report, 'Shaka recommends `gpt-6-sol`'
    refute blocked
  end

  def doctor_for(agents)
    report = nil
    blocked = nil
    with_repository('review' => review_policy('local_review_agents' => agents)) do |root|
      report, blocked = doctor(root:)
    end
    [report, blocked]
  end

  def test_an_unlisted_codex_effort_warns_without_blocking
    notice = notices('openai/codex', effort: 'maximum').fetch(0)

    assert_equal 'degraded', notice.fetch('severity')
    assert_includes notice.fetch('summary'), 'maximum'
  end
end
