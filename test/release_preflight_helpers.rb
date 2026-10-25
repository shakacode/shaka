# frozen_string_literal: true

require 'rubygems/package'
require 'digest'

module ReleasePreflightHelpers
  ROOT = File.expand_path('..', __dir__)
  COMMAND = File.join(ROOT, 'bin/release-preflight')

  def setup
    @directory = Dir.mktmpdir('release-preflight')
    @root = File.join(@directory, 'source')
    execute('git', 'clone', '--quiet', '--shared', ROOT, @root)
    execute('git', 'checkout', '-B', 'main')
    prepare_version
    prepare_artifact
  end

  def prepare_version
    File.write(File.join(@root, 'skills/shaka/lib/shaka/version.rb'),
               "module Shaka\n  VERSION = '0.1.0.pre.99'\nend\n")
    prepare_notes
    execute('git', 'add', '.')
    execute('git', '-c', 'user.name=Release Test', '-c', 'user.email=test@example.com', 'commit', '-qm',
            'Release fixture')
    @head = execute('git', 'rev-parse', 'HEAD').strip
    prepare_remote
  end

  def prepare_notes
    @notes = File.join(@directory, 'notes.md')
    File.write(@notes, "A tested prerelease.\n")
    File.write(File.join(@root, 'CHANGELOG.md'),
               "# Changelog\n\n## [0.1.0.pre.99]\n\nA tested prerelease.\n\n[0.1.0.pre.99]: https://example.com/release\n")
  end

  def prepare_remote
    @remote = File.join(@directory, 'origin.git')
    execute('git', 'clone', '--bare', '--quiet', @root, @remote)
    execute('git', 'remote', 'set-url', 'origin', @remote)
    execute('git', 'config', "url.#{@remote}.insteadOf", 'https://github.com/shakacode/shaka.git')
  end

  def prepare_artifact
    @gem = File.join(@directory, 'release.gem')
    execute('gem', 'build', 'shaka.gemspec', '--output', @gem)
    @validation = File.join(@directory, 'validation.json')
    write_validation
  end

  def teardown = FileUtils.remove_entry(@directory)

  private

  def write_validation
    require_relative '../skills/shaka/lib/shaka/evidence/result'
    _config, settings, source_kind, public_settings = Shaka::Evidence::Inputs.capture(
      root: @root, ref: @head, repository: 'shakacode/shaka',
      task_overrides: { 'command' => 'validate', 'arguments' => [] }
    )
    tree = execute('git', 'rev-parse', 'HEAD^{tree}').strip
    @evidence = evidence_body(tree, settings, source_kind, public_settings)
    File.write(@validation, JSON.generate(@evidence))
  end

  def evidence_body(tree, settings, source_kind, public_settings)
    { 'kind' => 'validation', 'command' => 'validate', 'status' => 'completed',
      'exit_code' => 0, 'tested_tree' => tree, 'tree_after' => tree, 'inputs_changed' => false,
      'settings' => settings, 'settings_after' => settings, 'source_kind' => source_kind,
      'source_ref' => @head, 'repository' => 'shakacode/shaka', 'public_settings' => public_settings,
      'task_overrides' => { 'command' => 'validate', 'arguments' => [] } }
  end

  def capture(**)
    Open3.capture3(RbConfig.ruby, COMMAND, '--commit', @head, '--gem', @gem,
                   '--validation', @validation, '--notes', @notes, chdir: @root, **)
  end

  def preflight
    output, error, status = capture
    assert_predicate status, :success?, error
    JSON.parse(output)
  end

  def assert_refused(message)
    output, error, status = capture
    refute_predicate status, :success?, output
    assert_empty output
    assert_includes error, message
  end

  def execute(*)
    output, error, status = Open3.capture3(*, chdir: File.directory?(@root) ? @root : @directory)
    assert_predicate status, :success?, error
    output
  end
end
