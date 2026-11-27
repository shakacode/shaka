# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/publication/settings'

# A PR published from a repository that never set Shaka up says so where a reader looks first.
class PublicationSettingsMissingTest < Minitest::Test
  include EvidenceFixture

  def test_a_checkout_without_a_settings_file_is_reported_missing_from_any_directory_in_it
    without_settings do |root, ref|
      assert_predicate prepare(root, nil, ref), :settings_missing?
      assert_predicate prepare(root, ref, ref), :settings_missing?
      assert_equal Shaka::PublicationSettings::NO_SETTINGS, prepare(root, nil, ref).path_redaction
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
      assert_equal Shaka::PublicationSettings::MISSING_REF, prepare(root, nil, ref).path_redaction
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

  def test_only_a_checkout_without_settings_renders_the_line
    line = Shaka::PublicationSettings::MISSING_LINE
    assert_includes line, 'Shaka settings were missing'
    without_settings { |root, ref| assert_equal [line], prepare(root, nil, ref).missing_lines }
    with_checkout { |root, ref| assert_empty prepare(root, nil, ref).missing_lines }
  end

  # A rendering preview pairs this renderer with an installed settings object that may predate the flag.
  def test_a_settings_object_without_the_flag_renders_no_line
    assert_empty Shaka::PublicationSettings.new.missing_lines
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
