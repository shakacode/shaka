# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/repository_config'

# The repository contract names every setting, so readers can browse them all in one file.
class RepositoryConfigurationExampleCoverageTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  # Settings with no packaged value, such as replacement_prompt_file, still appear, commented out when unset.
  def test_example_names_every_accepted_setting
    text = File.read(File.join(ROOT, Shaka::RepositoryConfig.load(root: ROOT).config_path))
    missing = accepted_settings.flat_map do |section, keys|
      scope = section ? text[/^#{section}:.*?(?=^\S|\z)/m] : text
      indent = section ? '\s+' : ''
      unnamed = keys.reject { |key| scope.match?(/^#{indent}(?:# )?(?:- )?#{key}:/) }
      unnamed.map { |key| [section, key].compact.join('.') }
    end
    assert_empty missing, 'Name these settings in the example, commented out when unset'
  end

  private

  def accepted_settings
    config = Shaka::RepositoryConfig
    { nil => config::Schema::REQUIRED + config::Schema::OPTIONAL,
      'review' => ['required', *config::Schema::OPTIONAL_REVIEW_KEYS],
      'merge' => ['preference', *config::MergeSchema::OPTIONAL],
      'checkpoint' => config::PostImplementationSchema::KEYS,
      'pr_description' => config::PrDescriptionSchema::KEYS + config::OpeningSchema::KEYS,
      'project_guidance' => config::ProjectGuidanceSchema::NAMES,
      'prose_limits' => Shaka::ProseLimits::DEFAULTS.keys,
      'branches' => config::BranchSchema::KEYS,
      'wip' => [config::WipSchema::KEY] }
  end
end
