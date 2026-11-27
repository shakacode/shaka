# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/publication/settings'
require 'shaka/publication/links'

# A PR published from a repository that never set Shaka up says so where a reader looks first.
class PublicationSettingsMissingTest < Minitest::Test
  include EvidenceFixture

  CONTENT = { 'deployment' => 'none' }.freeze

  def test_a_checkout_without_a_settings_file_is_reported_missing_from_any_directory_in_it
    without_settings do |root, ref|
      assert_predicate prepare(root, nil, ref), :settings_missing?
      assert_predicate prepare(root, ref, ref), :settings_missing?
      subdirectory = File.join(root, 'src')
      FileUtils.mkdir_p(subdirectory)
      assert_predicate prepare(subdirectory, nil, ref), :settings_missing?
    end
  end

  # Forgetting --ref in a repository with settings is a different recovery, which the settings block names.
  def test_a_checkout_with_settings_is_not_reported_missing
    with_checkout do |root, ref|
      refute_predicate prepare(root, nil, ref), :settings_missing?
      refute_predicate prepare(root, ref, ref), :settings_missing?
      refute_predicate prepare(File.join(root, '.agents'), nil, ref), :settings_missing?
    end
  end

  # An unusable settings entry is a repair, not a repository that never set Shaka up.
  def test_a_settings_entry_that_is_not_a_regular_file_is_not_reported_missing
    without_settings do |root, ref|
      FileUtils.mkdir_p(File.join(root, '.agents/shaka'))
      File.symlink(File.join(root, 'missing.yml'), File.join(root, '.agents/shaka/config.yml'))
      refute_predicate prepare(root, nil, ref), :settings_missing?
    end
  end

  def test_a_directory_outside_git_is_not_reported_missing
    Dir.mktmpdir { |directory| refute_predicate prepare(directory, nil, nil), :settings_missing? }
  end

  def test_the_lead_names_missing_settings_above_the_links
    missing = Object.new
    def missing.settings_missing? = true
    lead = Shaka::PublicationLinks.lead(CONTENT, nil, [], missing)
    assert_equal Shaka::PublicationLinks::SETTINGS_MISSING, lead.first
    assert_includes lead.first, 'Shaka settings were missing'
    refute_includes Shaka::PublicationLinks.lead(CONTENT, nil, [], Shaka::PublicationSettings.new),
                    Shaka::PublicationLinks::SETTINGS_MISSING
  end

  # A rendering preview pairs these renderers with an installed settings object that may predate the question.
  def test_an_older_settings_object_renders_without_the_line
    assert_equal 1, Shaka::PublicationLinks.lead(CONTENT, nil, [], Object.new).size
  end

  private

  def without_settings
    with_checkout do |root, _ref|
      git(root, 'rm', '-r', '--quiet', '.agents')
      commit(root)
      yield root, git(root, 'rev-parse', 'HEAD')
    end
  end

  def prepare(root, ref, head)
    pull = { 'changed_files' => 0, 'head' => { 'sha' => head }, 'base' => { 'sha' => ref } }
    Shaka::PublicationSettings.prepare(root:, ref:, pull:, options: { root: }, github: empty_diff)
                              .with_missing_settings(root)
  end

  def empty_diff
    Object.new.tap do |github|
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      def github.api_list(_path) = []
    end
  end
end
