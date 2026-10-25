# frozen_string_literal: true

require_relative 'release_install_support'
require 'shaka/install/official'

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

  def test_split_install_recovery_uses_the_winning_release
    split_install
    report = release_status
    assert_equal 'C5', report.fetch('state')
    output, status = Open3.capture2e({ 'HOME' => @home }, 'sh', '-c', report.fetch('next_command'))
    assert_predicate status, :success?, output
    %w[.claude .cursor].each do |host|
      assert_equal File.realpath(File.join(@installed, 'skills/shaka')),
                   File.realpath(File.join(@home, host, 'skills/shaka'))
    end
  end

  def test_missing_local_tag_requires_a_decision_instead_of_an_empty_fetch
    output, status = install_release
    assert_predicate status, :success?, output
    git('-C', @installed, 'update-ref', '-d', 'refs/tags/v0.1.0.pre.1')
    report = release_status
    assert_equal 'B4', report.fetch('state')
    assert(report.fetch('findings').all? { |finding| finding['next_command'].nil? })
  end

  def test_settings_location_recovery_distinguishes_release_versions
    @installed = File.join(@home, '.local/share/shaka/source')
    output, status = install_release
    assert_predicate status, :success?, output
    record = JSON.parse(File.read(File.join(@installed, '.git/shaka-install.json')))
    step = Shaka::Install::SettingsLocation.take_over(@root, @home, record.merge('release' => '0.1.0.pre.2'))
    assert_nil step
  end

  def test_status_text_names_the_pinned_release
    output, status = install_release
    assert_predicate status, :success?, output
    output, status = invoke('--directory', @installed, '--status')
    assert_predicate status, :success?, output
    assert_includes output, 'release 0.1.0.pre.1'
  end

  private

  def split_install
    output, status = invoke('--directory', @root, '--repository', @remote, '--agent', 'claude')
    assert_predicate status, :success?, output
    output, status = invoke('--directory', @installed, '--repository', @remote,
                            '--release', '0.1.0.pre.1', '--agent', 'cursor')
    assert_predicate status, :success?, output
    record = File.join(@installed, '.git/shaka-install.json')
    File.utime(Time.now + 2, Time.now + 2, record)
  end

  def release_status
    output, status = Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby,
                                     File.join(@installed, 'bin/install'), '--status', '--json')
    assert_predicate status, :success?, output
    JSON.parse(output)
  end

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
