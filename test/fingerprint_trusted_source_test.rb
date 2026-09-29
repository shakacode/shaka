# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/configuration/fingerprint'
require 'fileutils'

class FingerprintTrustedSourceTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir('fingerprint-trusted')
    FileUtils.mkdir_p(File.join(@root, '.agents/bin'))
    File.write(File.join(@root, '.agents/bin/test'), 'test')
    @settings = { 'commands' => { 'test' => '.agents/bin/test' }, 'review' => {}, 'opening_check' => {},
                  'paths' => { 'policy_configuration' => '.agents/agent-workflow.yml' } }
    @installation = { 'schema_version' => 1, 'version' => '1', 'source' => { 'kind' => 'uninstalled' } }
    system('git', '-C', @root, 'init', '--quiet', exception: true)
  end

  def teardown = FileUtils.remove_entry(@root)

  def commit_config(body)
    File.write(File.join(@root, '.agents/agent-workflow.yml'), body)
    system('git', '-C', @root, 'add', '.agents/agent-workflow.yml', exception: true)
    system('git', '-C', @root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '--quiet', '-m', 'config', exception: true)
    Open3.capture2('git', '-C', @root, 'rev-parse', 'HEAD').first.strip
  end

  def fingerprint(ref, settings = @settings)
    Shaka::Configuration::Fingerprint.build(root: @root, effective_settings: settings,
                                            repository: 'shakacode/shaka', installation: @installation,
                                            trusted_ref: ref)
  end

  def test_configuration_blob_changes_source_component
    first = fingerprint(commit_config('first'))
    second = fingerprint(commit_config('second'))
    refute_equal first.components.fetch('source'), second.components.fetch('source')
    assert_equal first.components.fetch('files'), second.components.fetch('files')
  end

  def test_prompt_bytes_change_file_component
    ref = commit_config('first')
    path = File.join(@root, 'review.md')
    File.write(path, 'one')
    settings = @settings.merge('review' => { 'prompt_file' => 'review.md' })
    first = fingerprint(ref, settings)
    File.write(path, 'two')
    refute_equal first.components.fetch('files'), fingerprint(ref, settings).components.fetch('files')
  end

  def test_symbolic_ref_and_missing_configuration_are_rejected
    assert_raises(Shaka::Error) { fingerprint('main') }
    assert_raises(Shaka::Error) { fingerprint('a' * 40) }
  end

  def test_configuration_path_must_name_a_blob
    ref = commit_config('first')
    settings = @settings.merge('paths' => { 'policy_configuration' => '.agents' })
    assert_raises(Shaka::Error) { fingerprint(ref, settings) }
  end
end
