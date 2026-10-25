# frozen_string_literal: true

require_relative 'release_install_support'

class ReleaseInstallLifecycleTest < Minitest::Test
  include ReleaseInstallSupport

  def test_upgrade_and_rollback_keep_previous_helpers_available
    output, status = install_release
    assert_predicate status, :success?, output
    helper = File.join(@installed, 'skills/shaka/scripts/shaka')
    original = File.binread(helper)
    newer = upgrade
    assert_equal original, File.binread(helper)
    assert_equal @release, git('-C', @installed, 'rev-parse', 'HEAD').strip
    rollback(newer)
  end

  private

  def upgrade
    publish_next_release
    newer = File.join(@directory, 'next-release')
    output, status = invoke('--directory', newer, '--release', '0.1.0.pre.2', '--take-over',
                            '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
    assert_equal File.realpath(File.join(newer, 'skills/shaka')), File.realpath(@destination)
    newer
  end

  def publish_next_release
    File.write(File.join(@source, 'lib/shaka/version.rb'), "module Shaka\n  VERSION = '0.1.0.pre.2'\nend\n")
    commit_source
    git('-C', @root, 'tag', 'v0.1.0.pre.2')
    git('-C', @root, 'push', '-q', 'origin', 'refs/tags/v0.1.0.pre.2')
  end

  def rollback(newer)
    output, status = invoke('--directory', @installed, '--release', '0.1.0.pre.1', '--take-over',
                            '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
    assert_equal File.realpath(File.join(@installed, 'skills/shaka')), File.realpath(@destination)
    assert_path_exists File.join(newer, 'skills/shaka/scripts/shaka')
  end
end
