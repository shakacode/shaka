# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/repository_config'

# The repository contract names every setting, so readers can browse them all in one file.
class RepositoryConfigurationExampleCoverageTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  CONFIG = Shaka::RepositoryConfig
  REVIEW = CONFIG::ReviewSchema
  # Every key the settings accept, by the path it nests under.
  ACCEPTED_SETTINGS = {
    nil => CONFIG::Schema::REQUIRED + CONFIG::Schema::OPTIONAL,
    'review' => ['required', *CONFIG::Schema::OPTIONAL_REVIEW_KEYS],
    'review.local_review_agents' => [*REVIEW::IDENTITY, REVIEW::PROMPT_FILE, REVIEW::MODEL, REVIEW::EFFORT],
    'merge' => ['preference', *CONFIG::MergeSchema::OPTIONAL],
    'merge.limits' => Shaka::MergeLimits::DEFAULTS.keys,
    'checkpoint' => CONFIG::PostImplementationSchema::KEYS,
    'pr_description' => CONFIG::PrDescriptionSchema::KEYS,
    'pr_description.opening_check' => CONFIG::OpeningSchema::KEYS,
    'pr_description.human_review_floors' => ['level', 'reason', *CONFIG::HumanReviewFloorSchema::LISTS],
    'project_guidance' => CONFIG::ProjectGuidanceSchema::NAMES,
    'prose_limits' => Shaka::ProseLimits::DEFAULTS.keys,
    'branches' => CONFIG::BranchSchema::KEYS,
    'wip' => [CONFIG::WipSchema::KEY]
  }.freeze

  # Settings with no packaged value, such as replacement_prompt_file, still appear, commented out when unset.
  def test_example_names_every_accepted_setting
    text = File.read(File.join(ROOT, Shaka::RepositoryConfig.load(root: ROOT).config_path))
    missing = ACCEPTED_SETTINGS.flat_map do |path, keys|
      scope = path ? block(text, path) : text
      keys.reject { |key| named?(scope, key) }.map { |key| [path, key].compact.join('.') }
    end
    assert_empty missing, 'Name these settings in the example, commented out when unset'
  end

  private

  # Only at the scope's own depth, so a deeper key of the same name cannot stand in for it.
  def named?(scope, key)
    child = scope[/^( *)\S/, 1].to_s
    item = scope.match?(/^#{child}- /) ? '(?:- |  )' : ''
    scope.match?(/^#{child}#{item}(?:# )?#{key}:/)
  end

  # The lines nested under a dotted path, such as pr_description.opening_check.
  def block(text, path)
    path.split('.').reduce(text) do |scope, key|
      start = scope.match(/^( *)#{key}:.*\n/)
      return '' unless start

      start.post_match.lines.take_while { |line| line.strip.empty? || line[/\A */].size > start[1].size }.join
    end
  end
end
