# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/defaults'
require 'shaka/repository_config'
require 'shaka/local_review/runner'
require 'shaka/post_implementation/risk'

# The repository contract doubles as the browsable example of shipped defaults.
class RepositoryConfigurationExampleTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  POLICY_KEYS = %w[
    required ci_review_jobs local_review_agents local_review_count post_implementation replacement_prompt_file
    provider_coverage custom_instructions_file time_zone
  ].freeze

  def setup
    config = Shaka::RepositoryConfig.load(root: ROOT)
    @example = YAML.safe_load_file(File.join(ROOT, config.config_path))
    minimal = { 'version' => 1, 'review' => { 'required' => 'none' }, 'merge' => { 'preference' => 'ask' } }
    @defaults = Shaka::RepositoryConfig.load(root: ROOT, source: YAML.dump(minimal),
                                             available_commands: config.commands.values).to_h
  end

  def test_example_includes_effective_default_sections
    @defaults.except('version', 'commands', 'paths', 'review', 'merge').each do |section, defaults|
      defaults = defaults.except('time_zone') if section == 'pr_description'
      assert_equal defaults, example_section(section), "Update the #{section} example when defaults change"
    end
  end

  def test_example_review_defaults_match_without_changing_repository_choices
    assert_equal @defaults.fetch('review').except(*POLICY_KEYS), @example.fetch('review').except(*POLICY_KEYS)
  end

  def test_example_merge_defaults_match_without_changing_repository_choices
    policy_keys = %w[preference required_checks]
    assert_equal @defaults.fetch('merge').except(*policy_keys), @example.fetch('merge').except(*policy_keys)
  end

  def test_example_post_implementation_defaults_match
    assert_equal Shaka::Defaults.fetch('checkpoint'),
                 @example.fetch('checkpoint').except('replacement_prompt_file')
  end

  def test_example_matches_packaged_defaults_without_changing_repository_choices
    Shaka::Defaults.data.except('runtime').each do |section, defaults|
      defaults.each do |key, value|
        next if POLICY_KEYS.include?(key) || key == 'preference'

        example = @example.fetch(section).fetch(key)
        example = example.except('reviewer') if key == 'opening_check' # This repository's choice.
        assert_equal value, example, "Update the #{section}.#{key} example"
      end
    end
  end

  def test_review_deadline_defaults_applied_outside_repository_config
    %w[anthropic/claude openai/codex xai/grok deepseek/openrouter].each do |reviewer|
      options = { reviewer: }
      Shaka::LocalReviewRunner.new(options).send(:validate_timeout!)
      timeouts = Shaka::Defaults.fetch('runtime', 'review_timeout_seconds')
      assert_equal timeouts.fetch(reviewer) { timeouts.fetch('default') }, options.fetch(:timeout_seconds)
    end
  end

  private

  def example_section(section)
    case section
    # The opening reviewer is this repository's choice, like the code reviewers.
    when 'opening_check' then @example.fetch('pr_description').fetch(section).except('reviewer')
    when 'pr_description' then @example.fetch(section).except('opening_check', 'time_zone')
    else @example.fetch(section)
    end
  end
end

# Shaka's own settings hold its merge and trust code from Auto, as the retired review floors did.
class RepositoryConfigurationExampleRiskAreasTest < Minitest::Test
  def test_shaka_merge_and_trust_code_counts_as_high
    areas = Shaka::RepositoryConfig.load(root: File.expand_path('..', __dir__)).high_risk_areas
    %w[skills/shaka/lib/shaka/merge_risk_gate.rb skills/shaka/lib/shaka/evidence/public_settings.rb
       skills/shaka/lib/shaka/trusted_config_source.rb
       skills/shaka/lib/shaka/repository_config/merge_schema.rb skills/shaka/config/post-implementation-risk.md
       skills/shaka/lib/shaka/post_implementation/adequacy.rb skills/shaka/lib/shaka/post_implementation_runner.rb
       skills/shaka/config/workflow.yml skills/shaka/SKILL.md skills/shaka/scripts/shaka.rb].each do |path|
      assert_equal 'merge_and_trust', Shaka::PostImplementationRisk.hits(areas, [path]).first&.fetch('area'), path
    end
  end
end
