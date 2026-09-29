# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/configuration/fingerprint'
require 'fileutils'

class FingerprintTest < Minitest::Test
  INSTALLATION = { 'schema_version' => 1, 'version' => '1.2', 'package_id' => 'package',
                   'source' => { 'kind' => 'revision', 'revision' => 'a' * 40,
                                 'content_sha256' => 'b' * 64 } }.freeze

  def setup
    @root = Dir.mktmpdir('fingerprint')
    FileUtils.mkdir_p(File.join(@root, '.agents/shaka/bin'))
    write('.agents/shaka/config.yml', "version: 1\n")
    write('.agents/shaka/bin/test', "#!/bin/sh\n")
    File.chmod(0o755, at('.agents/shaka/bin/test'))
    @settings = { 'version' => 1, 'review' => {}, 'opening_check' => {},
                  'commands' => { 'test' => '.agents/shaka/bin/test' },
                  'paths' => { 'policy_configuration' => '.agents/shaka/config.yml' } }
    @source = private_source
  end

  def teardown = FileUtils.remove_entry(@root)

  def at(path) = File.join(@root, path)
  def write(path, body) = File.write(at(path), body)
  def component(result, name) = result.components.fetch(name)

  def private_source
    entries = %w[.agents/shaka .agents/shaka/config.yml .agents/shaka/bin .agents/shaka/bin/test]
    inventory = entries.map { |path| { path: } }
    Struct.new(:root, :status, :ref, :inventory, :mode).new(@root, 'complete', 'c' * 40,
                                                            inventory, 'private/local')
  end

  def fingerprint(settings = @settings, installation: INSTALLATION, **source)
    source = { private_source: @source } if source.empty?
    Shaka::Configuration::Fingerprint.build(root: @root, effective_settings: settings,
                                            repository: 'shakacode/shaka', installation:, **source)
  end

  def test_semantic_hash_ignores_key_order_and_yaml_spelling
    first = fingerprint
    write('.agents/shaka/config.yml', "version: 01 # changed spelling\n")
    reordered = fingerprint(@settings.to_a.reverse.to_h)
    assert_equal first.digest, reordered.digest
    assert_equal 1, first.version
  end

  def test_script_bytes_change_only_file_component
    first = fingerprint
    write('.agents/shaka/bin/test', "#!/bin/sh\nexit 1\n")
    changed = fingerprint
    refute_equal component(first, 'files'), component(changed, 'files')
    assert_equal component(first, 'effective_settings'), component(changed, 'effective_settings')
    assert_equal component(first, 'source'), component(changed, 'source')
  end

  def test_effective_override_and_installation_change_their_components
    first = fingerprint
    override = fingerprint(@settings.merge('version' => 2))
    installed = fingerprint(installation: INSTALLATION.merge('version' => '1.3'))
    refute_equal component(first, 'effective_settings'), component(override, 'effective_settings')
    refute_equal component(first, 'installation'), component(installed, 'installation')
  end

  def test_executable_mode_changes_files
    first = component(fingerprint, 'files')
    File.chmod(0o644, at('.agents/shaka/bin/test'))
    refute_equal first, component(fingerprint, 'files')
  end

  def test_symlink_target_bytes_change_files
    File.symlink('test', at('.agents/shaka/bin/alias'))
    @source.inventory << { path: '.agents/shaka/bin/alias' }
    linked = component(fingerprint, 'files')
    write('.agents/shaka/bin/test', 'new bytes')
    refute_equal linked, component(fingerprint, 'files')
  end

  def test_private_inventory_includes_unreferenced_inputs
    first = component(fingerprint, 'files')
    write('.agents/shaka/extra-prompt.md', 'instructions')
    @source.inventory << { path: '.agents/shaka/extra-prompt.md' }
    refute_equal first, component(fingerprint, 'files')
  end

  def test_rejects_symlink_escape
    File.symlink('/etc/passwd', at('.agents/shaka/bin/escape'))
    @source.inventory << { path: '.agents/shaka/bin/escape' }
    assert_raises(Shaka::Error) { fingerprint }
  end

  def test_source_revision_changes_without_a_candidate_commit
    first = fingerprint
    @source.ref = 'd' * 40
    second = fingerprint
    refute_equal component(first, 'source'), component(second, 'source')
    assert_equal component(first, 'files'), component(second, 'files')
    refute first.to_h.key?('candidate_commit')
  end
end
