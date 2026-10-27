# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/configure_settings'

# Every setting Shaka accepts or defaults is reported, and links to the place the reference explains it.
class ConfigureSettingsCoverageTest < Minitest::Test
  SETTINGS = Shaka::ConfigureSettings::SETTINGS
  SCHEMA = Shaka::RepositoryConfig
  REFERENCE = File.expand_path('../docs/settings.md', __dir__)

  def test_every_setting_links_to_its_section_of_the_settings_reference
    anchors = File.read(REFERENCE).scan(/^## (.+)$/).flatten.map do |heading|
      heading.downcase.gsub(/[^a-z0-9 _-]/, '').tr(' ', '-')
    end

    assert_empty SETTINGS.map(&:anchor) - anchors
  end

  def test_every_packaged_default_belongs_to_a_reported_setting
    assert_empty(leaves(Shaka::Defaults.data.except('runtime')).reject { |path| covered?(path) })
  end

  def test_every_key_the_schema_accepts_belongs_to_a_reported_setting
    keys = SCHEMA::Schema::REQUIRED + SCHEMA::Schema::OPTIONAL +
           { 'review' => ['required', *SCHEMA::Schema::OPTIONAL_REVIEW_KEYS],
             'merge' => ['preference', *SCHEMA::MergeSchema::OPTIONAL],
             'pr_description' => SCHEMA::PrDescriptionSchema::KEYS, 'branches' => SCHEMA::BranchSchema::KEYS,
             'wip' => SCHEMA::WipSchema::KEYS }.flat_map { |section, names| names.map { |name| "#{section}.#{name}" } }

    assert_empty(keys.reject { |key| covered?(key) })
  end

  private

  def leaves(node, prefix = nil)
    return [prefix] unless node.is_a?(Hash) && !node.empty?

    node.flat_map { |key, value| leaves(value, [prefix, key].compact.join('.')) }
  end

  # A key is covered by its own setting, a setting it falls under, or, for a section, a setting inside it.
  def covered?(key)
    SETTINGS.flat_map { |setting| [setting.key, *setting.aliases] }.any? do |name|
      key == name || key.start_with?("#{name}.") || name.start_with?("#{key}.")
    end
  end
end

# The report reads one settings source and shows each value beside its default.
class ConfigureSettingsCommandTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_rows_say_what_the_repository_sets_and_whether_it_matches_the_default
    merge = merge_policy.merge('limits' => { 'max_commits' => 9 }, 'auto_max_review_floor' => 3)
    with_trusted('merge' => merge) do |root, ref|
      rows = rows(report(root, '--ref', ref))

      assert_equal [true, true], rows.fetch('merge.limits').values_at('set', 'matches_default')
      assert_equal [true, false, 3, 5], rows.fetch('merge.auto_max_review_floor')
                                            .values_at('set', 'matches_default', 'effective', 'default')
      assert_equal [false, nil, 1], rows.fetch('review.local_review_count')
                                        .values_at('set', 'matches_default', 'effective')
    end
  end

  def test_the_checkpoint_shows_the_settings_its_runner_applies
    with_trusted('checkpoint' => { 'reviewer' => 'anthropic/claude' }) do |root, ref|
      checkpoint = rows(report(root, '--ref', ref)).fetch('checkpoint')

      assert_equal 'anthropic/claude', checkpoint.dig('effective', 'reviewer')
      refute checkpoint.fetch('effective').key?('model')
      refute checkpoint.fetch('matches_default')
    end
  end

  def test_an_earlier_setting_name_reports_as_set
    with_trusted('wip' => { 'include_locations' => false }) do |root, ref|
      row = rows(report(root, '--ref', ref)).fetch('wip.include_checkout_path')

      assert_equal [true, 'wip.include_locations', false], row.values_at('set', 'set_as', 'effective')
    end
  end

  def test_a_selected_settings_preview_supplies_the_settings
    with_trusted do |root, ref|
      preview = preview_commit(root, 'repo_prefix' => 'PREV')
      Shaka::Configuration::SettingsPreview.new(root:).start(preview)
      document = report(root, '--ref', ref)

      assert_equal [ref, preview, 'preview/local'], document.values_at('requested_ref', 'settings_ref', 'source')
      assert_equal 'PREV', rows(document).fetch('repo_prefix').fetch('effective')
    end
  end

  def test_a_local_draft_reads_the_working_tree
    with_trusted do |root, _ref|
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(seam('repo_prefix' => 'DRFT')))
      document = report(root, '--local')

      assert_equal ['untrusted draft', true], document.values_at('source', 'draft')
      assert_equal 'DRFT', rows(document).fetch('repo_prefix').fetch('effective')
    end
  end

  def test_one_settings_source_is_required
    with_trusted do |root, ref|
      [['--ref', ref, '--local'], [], ['--ref', 'main']].each do |arguments|
        _, error, status = Open3.capture3(*SHAKA_COMMAND, 'configure', 'settings', '--root', root, *arguments)

        refute_predicate status, :success?, arguments.join(' ')
        assert_match(/--ref|--local/, error)
      end
    end
  end

  private

  def with_trusted(overrides = {})
    with_repository(overrides) do |root|
      git!(root, 'init', '--quiet')
      commit!(root, 'trusted')
      yield root, git!(root, 'rev-parse', 'HEAD').strip
    end
  end

  def preview_commit(root, overrides)
    git!(root, 'switch', '--quiet', '-c', 'settings-preview')
    File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(seam(overrides)))
    commit!(root, 'preview')
    git!(root, 'rev-parse', 'HEAD').strip.tap { git!(root, 'switch', '--quiet', '-') }
  end

  def report(root, *)
    output, error, status = Open3.capture3(*SHAKA_COMMAND, 'configure', 'settings', '--root', root, *)
    assert_predicate status, :success?, "#{output}\n#{error}"
    JSON.parse(output)
  end

  def rows(document) = document.fetch('settings').to_h { |row| [row.fetch('key'), row] }

  def commit!(root, message)
    git!(root, 'add', '-A')
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--quiet', '-m', message)
  end

  def git!(root, *)
    output, status = Open3.capture2e(TEST_GIT, '-C', root, *)
    raise output unless status.success?

    output
  end
end
