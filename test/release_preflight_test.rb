# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'json'
require_relative 'release_preflight_helpers'

class ReleasePreflightTest < Minitest::Test
  include ReleasePreflightHelpers

  def test_binds_the_actual_package_and_commit_without_publishing
    result = preflight
    assert_equal ['ready_for_approval', @head, '0.1.0.pre.99'], result.values_at('status', 'commit', 'version')
    assert_equal Digest::SHA256.file(@gem).hexdigest, result.fetch('gem_sha256')
    refute result.fetch('publication_authorized')
    assert_empty execute('git', 'ls-remote', '--tags', 'origin', 'refs/tags/v0.1.0.pre.99')
    assert_equal '', execute('git', 'status', '--porcelain')
  end

  def test_rejects_a_dirty_checkout
    File.write(File.join(@root, 'README.md'), 'changed')
    assert_refused 'clean checkout'
  end

  def test_rejects_another_commit
    @head = execute('git', 'rev-parse', 'HEAD^').strip
    assert_refused 'HEAD'
  end

  def test_rejects_outdated_main
    execute('git', '--git-dir', @remote, 'update-ref', 'refs/heads/main', "#{@head}^")
    assert_refused 'remote main'
  end

  def test_rejects_failed_missing_or_stale_validation
    [nil, { 'exit_code' => 1 }, { 'inputs_changed' => true }, { 'tested_tree' => 'a' * 40 },
     { 'command' => 'test' }].each do |change|
      write_validation
      change ? File.write(@validation, JSON.generate(@evidence.merge(change))) : File.unlink(@validation)
      assert_refused 'validation'
    end
  end

  def test_rejects_changed_package_even_with_the_same_version
    path = File.join(@root, 'README.md')
    original = File.binread(path)
    File.write(path, 'wrong artifact')
    execute('gem', 'build', 'shaka.gemspec', '--output', @gem)
    File.binwrite(path, original)
    assert_refused 'package content'
  end

  def test_rejects_different_package_metadata
    # Build altered metadata without changing the release source or its version.
    script = "s = Gem::Specification.load('shaka.gemspec'); s.required_ruby_version = '>= 4'; " \
             'Gem::Package.build(s, false, false, ARGV.fetch(0))'
    execute(RbConfig.ruby, '-rrubygems/package', '-e', script, @gem)
    assert_refused 'metadata'
  end

  def test_rejects_a_corrupt_gem
    File.write(@gem, 'not a gem')
    output, _error, status = capture
    refute_predicate status, :success?
    assert_empty output
  end

  def test_rejects_ignored_files_in_the_package
    exclude = execute('git', 'rev-parse', '--git-path', 'info/exclude').strip
    File.write(File.expand_path(exclude, @root), "docs/release-extra.md\n")
    File.write(File.join(@root, 'docs/release-extra.md'), 'uncommitted content')
    execute('gem', 'build', 'shaka.gemspec', '--output', @gem)
    assert_refused 'committed source'
  end

  def test_rejects_uncommitted_modes_even_when_git_ignores_them
    execute('git', 'config', 'core.filemode', 'false')
    File.chmod(0o644, File.join(@root, 'exe/shaka'))
    execute('gem', 'build', 'shaka.gemspec', '--output', @gem)
    assert_refused 'committed source'
  end

  def test_rejects_missing_or_different_notes
    File.write(@notes, 'unreviewed notes')
    assert_refused 'changelog'
    File.unlink(@notes)
    assert_refused 'notes'
  end

  def test_rejects_existing_tag
    execute('git', '--git-dir', @remote, 'tag', 'v0.1.0.pre.99', @head)
    assert_refused 'already exists'
  end
end
