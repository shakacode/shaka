# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/configuration/fingerprint'
require 'fileutils'

class FingerprintBoundaryTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir('fingerprint-boundary')
    FileUtils.mkdir_p(File.join(@root, '.agents/shaka'))
    File.write(File.join(@root, '.agents/shaka/config.yml'), 'version: 1')
    @settings = { 'commands' => {}, 'review' => {}, 'opening_check' => {},
                  'paths' => { 'policy_configuration' => '.agents/shaka/config.yml' } }
    @source = Struct.new(:root, :status, :ref, :inventory, :mode).new(
      @root, 'complete', 'a' * 40, [{ path: '.agents/shaka/config.yml' }], 'private/local'
    )
    @installation = { 'schema_version' => 1, 'version' => '1', 'source' => { 'kind' => 'uninstalled' } }
  end

  def teardown = FileUtils.remove_entry(@root)

  def fingerprint(settings = @settings, **options)
    Shaka::Configuration::Fingerprint.build(root: @root, effective_settings: settings,
                                            repository: options.fetch(:repository, 'shakacode/shaka'),
                                            installation: options.fetch(:installation, @installation),
                                            private_source: @source)
  end

  def test_private_source_command_override_outside_inventory_is_hashed
    path = File.join(@root, 'ci.sh')
    File.write(path, 'first')
    settings = @settings.merge('commands' => { 'test' => 'ci.sh' })
    first = fingerprint(settings).components.fetch('files')
    File.write(path, 'second')
    refute_equal first, fingerprint(settings).components.fetch('files')
  end

  def test_rejects_incomplete_private_source_independently
    @source.status = 'partial'
    assert_raises(Shaka::Error) { fingerprint }
  end

  def test_missing_settings_key_is_a_shaka_error
    assert_raises(Shaka::Error) { fingerprint(@settings.except('review')) }
  end

  def test_invalid_encoding_is_a_shaka_error
    settings = @settings.merge('note' => "\xFF".b)
    assert_raises(Shaka::Error) { fingerprint(settings) }
  end

  def test_rejects_unsafe_command_path
    settings = @settings.merge('commands' => { 'test' => '../outside' })
    assert_raises(Shaka::Error) { fingerprint(settings) }
  end

  def test_rejects_command_through_parent_symlink_outside_repository
    Dir.mktmpdir('outside-fingerprint') do |outside|
      File.write(File.join(outside, 'test'), 'external')
      File.symlink(outside, File.join(@root, 'link'))
      settings = @settings.merge('commands' => { 'test' => 'link/test' })
      assert_raises(Shaka::Error) { fingerprint(settings) }
    end
  end

  def test_rejects_trailing_slash_on_directory_symlink
    Dir.mktmpdir('outside-fingerprint') do |outside|
      File.symlink(outside, File.join(@root, 'escape-dir'))
      settings = @settings.merge('commands' => { 'test' => 'escape-dir/' })
      assert_raises(Shaka::Error) { fingerprint(settings) }
    end
  end

  def test_rejects_nul_byte_in_path
    settings = @settings.merge('commands' => { 'test' => "test\0path" })
    assert_raises(Shaka::Error) { fingerprint(settings) }
  end

  def test_rejects_wrong_worktree_and_symbolic_private_ref
    @source.root = Dir.tmpdir
    assert_raises(Shaka::Error) { fingerprint }
    @source.root = @root
    @source.ref = 'main'
    assert_raises(Shaka::Error) { fingerprint }
  end

  def test_missing_root_is_a_shaka_error
    @source.root = File.join(@root, 'deleted')
    assert_raises(Shaka::Error) { fingerprint }
  end

  def test_source_selection_requires_exactly_one_source
    options = { root: @root, effective_settings: @settings, repository: 'shakacode/shaka',
                installation: @installation }
    builder = Shaka::Configuration::Fingerprint
    assert_raises(Shaka::Error) { builder.build(**options) }
    assert_raises(Shaka::Error) { builder.build(**options, private_source: @source, trusted_ref: 'a' * 40) }
  end
end
