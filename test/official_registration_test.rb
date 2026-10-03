# frozen_string_literal: true

require_relative 'official_install_support'

class OfficialRegistrationTest < Minitest::Test
  include OfficialInstallSupport

  def test_ruby_repair_reuses_registered_hosts_without_adding_codex
    official_install
    File.unlink(File.join(@root, '.git/shaka-ruby'))
    output, status = invoke
    assert_predicate status, :success?, output
    assert File.symlink?(@destination)
    refute File.symlink?(File.join(@home, '.agents/skills/shaka'))
  end

  def test_adding_a_tower_reuses_the_registered_host
    official_install
    output, status = invoke('--with-rct')
    assert_predicate status, :success?, output
    assert File.symlink?(@rct_destination)
    refute File.symlink?(File.join(@home, '.agents/skills/shaka'))
  end

  def test_rejects_group_writable_files_and_nested_directories
    [File.join(@source, 'SKILL.md'), File.join(@source, 'scripts')].each do |path|
      original = File.stat(path).mode
      File.chmod(original | 0o020, path)
      output, status = invoke('--directory', @root, '--repository', @remote, '--skills-dir', @skills_dir)
      refute_predicate status, :success?
      assert_includes output, 'group or world writable'
      refute File.symlink?(@destination)
      File.chmod(original, path)
    end
  end

  def test_maintenance_refuses_new_selections_before_mutating_links
    official_install
    [%w[--update --agent codex], %w[--verify --with-rct], ['--update', '--skills-dir', @skills_dir]].each do |flags|
      output, status = invoke(*flags)
      refute_predicate status, :success?
      assert_includes output, 'Use bin/install to change selected hosts or towers'
    end
    refute File.symlink?(File.join(@home, '.agents/skills/shaka'))
  end
end
