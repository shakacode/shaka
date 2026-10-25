# frozen_string_literal: true

require_relative 'seam_initializer_layout_test'
require_relative 'repository_fixture'
require_relative 'doctor_helper'
require 'shaka/configuration/fingerprint'

# seam init shows the checkpoint's default added file, and settings warn when it is ignored.
class CheckpointExtraPromptSeamInitTest < Minitest::Test
  include SeamInitializerTestHelpers
  include SeamInitializerLayoutHelpers

  def test_init_writes_the_default_added_file_as_a_commented_setting
    with_repository do |root|
      _, error, status = init(root)
      config = File.read(File.join(root, '.agents/shaka/config.yml'))

      assert_predicate status, :success?, error
      assert_includes config, "# checkpoint:\n"
      assert_includes config, "#   extra_prompt_file: .agents/shaka/prompts/checkpoint.md\n"
      refute YAML.safe_load(config).key?('checkpoint')
    end
  end

  def test_repeat_init_accepts_a_configuration_written_before_the_commented_defaults
    with_repository do |root|
      init(root)
      config = File.join(root, '.agents/shaka/config.yml')
      File.write(config, File.read(config).split("#\n# Defaults you can change").first)
      _, error, status = init(root)

      assert_predicate status, :success?, error
    end
  end
end

class CheckpointExtraPromptWarningTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers

  DEFAULT = '.agents/shaka/prompts/checkpoint.md'

  def test_a_default_file_beside_a_named_one_is_reported_as_ignored
    with_repository('checkpoint' => { 'extra_prompt_file' => '.agents/named.md' }) do |root|
      File.write(File.join(root, '.agents/named.md'), 'Named rule')
      assert_empty Shaka::RepositoryConfig.load(root:).warnings

      FileUtils.mkdir_p(File.join(root, File.dirname(DEFAULT)))
      File.write(File.join(root, DEFAULT), 'Default rule')
      assert_equal ["#{DEFAULT} is ignored because checkpoint.extra_prompt_file names .agents/named.md; " \
                    'delete it or point the setting back'], Shaka::RepositoryConfig.load(root:).warnings
    end
  end

  def test_doctor_reports_the_ignored_file_and_still_checks_reviewers
    with_repository('checkpoint' => { 'extra_prompt_file' => '.agents/named.md' }) do |root|
      File.write(File.join(root, '.agents/named.md'), 'Named rule')
      FileUtils.mkdir_p(File.join(root, File.dirname(DEFAULT)))
      File.write(File.join(root, DEFAULT), 'Default rule')
      report, = doctor(root:)

      assert_includes report, '[DEGRADED] Repository seam'
      assert_includes report, "#{DEFAULT} is ignored"
      refute_includes report, 'not checked: repository seam is not healthy'
    end
  end

  def test_a_named_file_that_is_missing_fails_settings_validation
    with_repository('checkpoint' => { 'extra_prompt_file' => '.agents/absent.md' }) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_includes error.message, 'checkpoint.extra_prompt_file'
    end
  end
end

class CheckpointExtraPromptFingerprintTest < Minitest::Test
  RULES = '.agents/shaka/prompts/checkpoint.md'

  def setup
    @root = Dir.mktmpdir('fingerprint-extra-prompt')
    FileUtils.mkdir_p(File.join(@root, '.agents/bin'))
    File.write(File.join(@root, '.agents/bin/test'), 'test')
    File.write(File.join(@root, '.agents/agent-workflow.yml'), 'config')
    system('git', '-C', @root, 'init', '--quiet', exception: true)
  end

  def teardown = FileUtils.remove_entry(@root)

  def test_a_committed_default_file_changes_the_file_component
    absent = files(commit)
    FileUtils.mkdir_p(File.join(@root, File.dirname(RULES)))
    File.write(File.join(@root, RULES), 'one')
    first = files(commit)
    File.write(File.join(@root, RULES), 'two')

    refute_equal absent, first
    refute_equal first, files(commit)
  end

  private

  def commit
    system('git', '-C', @root, 'add', '.', exception: true)
    system('git', '-C', @root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '--quiet', '--allow-empty', '-m', 'change', exception: true)
    Open3.capture2('git', '-C', @root, 'rev-parse', 'HEAD').first.strip
  end

  def files(ref)
    settings = { 'commands' => { 'test' => '.agents/bin/test' }, 'review' => {}, 'opening_check' => {},
                 'paths' => { 'policy_configuration' => '.agents/agent-workflow.yml' } }
    installation = { 'schema_version' => 1, 'version' => '1', 'source' => { 'kind' => 'uninstalled' } }
    Shaka::Configuration::Fingerprint.build(root: @root, effective_settings: settings, repository: 'shakacode/shaka',
                                            installation:, trusted_ref: ref).components.fetch('files')
  end
end
