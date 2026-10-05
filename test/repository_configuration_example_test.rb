# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/repository_config'

# The repository contract doubles as the browsable example of shipped defaults.
class RepositoryConfigurationExampleTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  POLICY_KEYS = %w[required ci_review_jobs local_review_agents local_review_count post_implementation].freeze

  def setup
    config = Shaka::RepositoryConfig.load(root: ROOT)
    @example = YAML.safe_load_file(File.join(ROOT, config.config_path))
    minimal = { 'version' => 1, 'review' => { 'required' => 'none' }, 'merge' => { 'preference' => 'ask' } }
    @defaults = Shaka::RepositoryConfig.load(root: ROOT, source: YAML.dump(minimal),
                                             available_commands: config.commands.values).to_h
  end

  def test_example_includes_effective_default_sections
    @defaults.except('version', 'commands', 'paths', 'review', 'merge').each do |section, defaults|
      example = section == 'opening_check' ? @example.fetch('pr_description').fetch(section) : @example.fetch(section)
      assert_equal defaults, example, "Update the #{section} example when defaults change"
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
    defaults = Shaka::RepositoryConfig::PostImplementationSchema::DEFAULTS.merge('enabled' => true)
    assert_equal defaults, @example.fetch('review').fetch('post_implementation')
  end
end
