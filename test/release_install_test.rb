# frozen_string_literal: true

require_relative 'release_install_support'

class ReleaseInstallTest < Minitest::Test
  include ReleaseInstallSupport

  def test_release_installs_tagged_code_and_maintenance_does_not_follow_main
    output, status = install_release
    assert_predicate status, :success?, output
    assert_equal @release, git('-C', @installed, 'rev-parse', 'HEAD').strip
    assert_equal 'version one', File.read(File.join(@destination, 'SKILL.md'))
    output, status = invoke('--directory', @installed, '--update')
    assert_predicate status, :success?, output
    assert_equal @release, git('-C', @installed, 'rev-parse', 'HEAD').strip
    assert_healthy_status
  end

  def test_moved_release_tag_cannot_replace_the_installed_release
    output, status = install_release
    assert_predicate status, :success?, output
    move_release_tag
    output, status = invoke('--directory', @installed, '--update')
    refute_predicate status, :success?, output
    assert_equal @release, git('-C', @installed, 'rev-parse', 'HEAD').strip
    assert_equal 'version one', File.read(File.join(@destination, 'SKILL.md'))
  end

  def test_take_over_cannot_repin_the_same_release_after_its_tag_moves
    output, status = install_release
    assert_predicate status, :success?, output
    move_release_tag
    output, status = invoke('--directory', File.join(@directory, 'moved'), '--take-over', '--skills-dir', @skills_dir)
    refute_predicate status, :success?, output
    assert_includes output, 'Release tag changed'
    assert_equal File.realpath(File.join(@installed, 'skills/shaka')), File.realpath(@destination)
  end

  def test_missing_release_leaves_existing_links_untouched
    official_install
    old = File.realpath(@destination)
    output, status = install_release('9.9.9')
    refute_predicate status, :success?, output
    assert_equal old, File.realpath(@destination)
  end

  def test_annotated_release_tag_is_resolved_to_its_commit
    git('-C', @root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
        'tag', '-a', '-f', 'v0.1.0.pre.1', @release, '-m', 'release')
    git('-C', @root, 'push', '-q', '--force', 'origin', 'refs/tags/v0.1.0.pre.1')
    output, status = install_release
    assert_predicate status, :success?, output
    output, status = invoke('--directory', @installed, '--update')
    assert_predicate status, :success?, output
    assert_equal @release, git('-C', @installed, 'rev-parse', 'HEAD').strip
  end

  def test_version_mismatch_cannot_be_registered_on_retry
    git('-C', @root, 'tag', 'v1.0.0', @release)
    git('-C', @root, 'push', '-q', 'origin', 'refs/tags/v1.0.0')
    2.times do
      output, status = install_release('1.0.0')
      refute_predicate status, :success?, output
      assert_includes output, 'Release version mismatch'
      refute_path_exists File.join(@installed, '.git/shaka-install.json')
    end
  end

  def test_release_requires_its_tag_even_when_a_branch_has_the_same_name
    git('-C', @root, 'push', '-q', 'origin', 'HEAD:refs/heads/v9.9.9')
    output, status = install_release('9.9.9')
    refute_predicate status, :success?, output
    refute_path_exists File.join(@installed, '.git/shaka-install.json')
  end

  def test_release_and_branch_cannot_be_selected_together
    output, status = invoke('--release', '1.0.0', '--branch', 'main')
    refute_predicate status, :success?, output
    assert_includes output, 'Choose --branch or --release'
  end

  private

  def move_release_tag
    git('-C', @root, 'tag', '-f', 'v0.1.0.pre.1')
    git('-C', @root, 'push', '-q', '--force', 'origin', 'refs/tags/v0.1.0.pre.1')
  end

  def assert_healthy_status
    output, status = Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby,
                                     File.join(@installed, 'bin/install'), '--status', '--json')
    assert_predicate status, :success?, output
    assert_empty JSON.parse(output).fetch('findings')
  end
end
