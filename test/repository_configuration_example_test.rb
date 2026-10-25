# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/defaults'
require 'shaka/repository_config'
require 'shaka/local_review/runner'
require 'shaka/publication/review_effort_floor'

# The repository contract doubles as the browsable example of shipped defaults.
class RepositoryConfigurationExampleTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  POLICY_KEYS = %w[
    required ci_review_jobs local_review_agents local_review_count post_implementation replacement_prompt_file
    provider_coverage
    human_review_floors auto_max_review_floor
  ].freeze
  # The only files this repository removes from a shipped floor: its Ruby library code leaves the
  # agent-instructions floor so merge.auto_max_review_floor can merge it.
  FLOOR_EXEMPTIONS = { 'changes agent instructions' => %w[skills/shaka/lib/**/*.rb] }.freeze
  # Where this repository's floors put its files; Auto merges only those at 2 or below.
  FLOOR_LEVELS = {
    'skills/shaka/lib/shaka/doctor/checks.rb' => 2, 'test/doctor_test.rb' => 2,
    'skills/shaka/lib/shaka/install/links.rb' => 3, 'bin/validate' => 3, '.rubocop.yml' => 3,
    'skills/shaka/SKILL.md' => 3,
    'skills/shaka/lib/shaka/required_checks.rb' => 4, 'skills/shaka/lib/shaka/merge_review_floor.rb' => 4,
    'skills/shaka/lib/shaka/publication/review_effort_floor.rb' => 4,
    'skills/shaka/lib/shaka/repository_config/merge_schema.rb' => 4, 'docs/settings.md' => 5,
    'skills/shaka/lib/AGENTS.md' => 3, 'test/AGENTS.md' => 3
  }.freeze

  def setup
    config = Shaka::RepositoryConfig.load(root: ROOT)
    @example = YAML.safe_load_file(File.join(ROOT, config.config_path))
    minimal = { 'version' => 1, 'review' => { 'required' => 'none' }, 'merge' => { 'preference' => 'ask' } }
    @defaults = Shaka::RepositoryConfig.load(root: ROOT, source: YAML.dump(minimal),
                                             available_commands: config.commands.values).to_h
  end

  def test_example_includes_effective_default_sections
    @defaults.except('version', 'commands', 'paths', 'review', 'merge').each do |section, defaults|
      defaults = defaults.except('human_review_floors') if section == 'pr_description'
      assert_equal defaults, example_section(section), "Update the #{section} example when defaults change"
    end
  end

  def test_example_review_defaults_match_without_changing_repository_choices
    assert_equal @defaults.fetch('review').except(*POLICY_KEYS), @example.fetch('review').except(*POLICY_KEYS)
  end

  def test_example_merge_defaults_match_without_changing_repository_choices
    policy_keys = %w[preference required_checks auto_max_review_floor]
    assert_equal @defaults.fetch('merge').except(*policy_keys), @example.fetch('merge').except(*policy_keys)
  end

  def test_example_post_implementation_defaults_match
    assert_equal Shaka::Defaults.fetch('checkpoint'), @example.fetch('checkpoint').except('replacement_prompt_file')
  end

  def test_example_matches_packaged_defaults_without_changing_repository_choices
    Shaka::Defaults.data.except('runtime').each do |section, defaults|
      defaults.each do |key, value|
        next if POLICY_KEYS.include?(key) || key == 'preference'

        assert_equal value, @example.fetch(section).fetch(key), "Update the #{section}.#{key} example"
      end
    end
  end

  # This repository adds its own floors and paths but keeps every shipped floor, removing files from
  # one only through FLOOR_EXEMPTIONS.
  def test_example_floors_keep_every_shipped_floor
    floors = @example.fetch('pr_description').fetch('human_review_floors')
    Shaka::Defaults.fetch('pr_description', 'human_review_floors').each { |shipped| assert_floor_kept(shipped, floors) }
  end

  # A misspelled path would let that code fall to floor 2 and merge without a person.
  def test_example_floor_paths_this_repository_adds_name_real_files
    shipped = Shaka::Defaults.fetch('pr_description', 'human_review_floors').flat_map { |floor| floor['paths'] }
    added = @example.fetch('pr_description').fetch('human_review_floors').flat_map { |floor| floor['paths'] } - shipped
    added.flat_map { |glob| alternatives(glob) }.each { |glob| refute_empty Dir.glob(glob, base: ROOT), glob }
  end

  def test_example_floors_hold_settings_merge_and_install_code_above_code_fixes
    floors = @example.fetch('pr_description').fetch('human_review_floors')
    levels = FLOOR_LEVELS.to_h { |path, _| [path, Shaka::ReviewEffortFloor.for([path], floors).fetch('level')] }
    assert_equal FLOOR_LEVELS, levels
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

  def assert_floor_kept(shipped, floors)
    floor = floors.find { |candidate| candidate.values_at('level', 'reason') == shipped.values_at('level', 'reason') }
    assert floor, "Keep the shipped floor: #{shipped['reason']}"
    assert_empty shipped.fetch('paths', []) - floor.fetch('paths', []), shipped['reason']
    assert_equal kept_floor(shipped, floor), floor, shipped['reason']
  end

  # Each name in a brace list, so one real file cannot hide a misspelled one beside it.
  def alternatives(glob)
    match = glob.match(/\{([^{}]*)\}/)
    match ? match[1].split(',').flat_map { |name| alternatives(match.pre_match + name + match.post_match) } : [glob]
  end

  # A kept floor may add paths; its except may add only this repository's exemptions.
  def kept_floor(shipped, floor)
    except = shipped.fetch('except', []) + FLOOR_EXEMPTIONS.fetch(shipped['reason'], [])
    shipped.merge('paths' => floor['paths'], 'except' => except).reject { |_, value| value == [] }
  end

  def example_section(section)
    case section
    when 'opening_check' then @example.fetch('pr_description').fetch(section)
    when 'pr_description' then @example.fetch(section).except('opening_check', 'human_review_floors')
    else @example.fetch(section)
    end
  end
end
