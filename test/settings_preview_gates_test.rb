# frozen_string_literal: true

require_relative 'settings_preview_fixture'
require_relative 'cli_final_preparation_test'
require_relative 'support/private_trial_github'

class SettingsPreviewGatesTest < Minitest::Test
  include SettingsPreviewFixture

  def test_preview_replaces_shaka_fallback_checks
    with_preview_repository do |root, trusted, preview|
      select_preview(root, preview)
      result = read_status(root, trusted, [])
      assert_equal 'github', result['requiredChecksSource']
      assert_empty result['requiredChecks']
    end
  end

  def test_live_required_checks_remain_authoritative
    with_preview_repository do |root, trusted, preview|
      select_preview(root, preview)
      required = [{ 'name' => 'live-required', 'state' => 'PENDING', 'bucket' => 'pending' }]
      result = read_status(root, trusted, required)
      assert_equal 'github', result['requiredChecksSource']
      assert_equal required, result['requiredChecks']
    end
  end

  private

  def read_status(root, ref, required)
    Dir.mktmpdir do |bin|
      prepare_github(bin, ref, required)
      output, error, status = Open3.capture3({ 'PATH' => "#{bin}:#{ENV.fetch('PATH')}" }, *COMMAND,
                                             'pr', 'owner/repo', '1', '--root', root, '--ref', ref)
      assert_predicate status, :success?, error
      JSON.parse(output)
    end
  end

  def prepare_github(bin, ref, required)
    script = PrivateTrialGitHub::SCRIPT.sub(
      "[{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]",
      "ARGV.include?('--required') ? fixture.fetch('required') : []"
    )
    File.write(File.join(bin, 'gh'), "#!#{RbConfig.ruby}\n#{script}")
    File.chmod(0o755, File.join(bin, 'gh'))
    File.write(File.join(bin, 'fixture.json'), JSON.generate('head' => ref, 'body' => '', 'required' => required))
  end
end

class SettingsPreviewFinalPreparationTest < Minitest::Test
  include FinalPreparationFixture

  def test_a_preview_cannot_disable_the_checkpoint
    with_fixture do |root, _ref, bin|
      error = assert_raises(Shaka::Error) { start_disabled_preview(root) }
      assert_includes error.message, 'checkpoint.enabled was removed'
      refute_path_exists File.join(bin, 'written')
    end
  end

  private

  def start_disabled_preview(root)
    change_candidate(root)
    commit_root(root)
    preview = Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip
    Shaka::Configuration::SettingsPreview.new(root:).start(preview)
  end
end
