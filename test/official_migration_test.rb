# frozen_string_literal: true

require_relative 'official_install_support'

class OfficialMigrationTest < Minitest::Test
  include OfficialInstallSupport

  def test_preserves_towers_and_retained_copies_while_removing_duplicate_codex_link
    prepare_migration
    output, status = invoke('--directory', @root, '--repository', @remote, '--agent', 'codex')
    assert_predicate status, :success?, output
    assert_equal File.realpath(@rct_source), File.readlink(File.join(@skills_dir, 'rct'))
    refute File.symlink?(File.join(@aliases, 'shaka'))
    assert File.symlink?(File.join(@skills_dir, 'shaka-pr-trial'))
    assert_retained_package
  end

  private

  def assert_retained_package
    assert File.file?(File.join(@package, 'skills/shaka/SKILL.md'))
    assert File.file?(File.join(@package, '.shaka-install.json'))
  end

  def prepare_migration
    @skills_dir = File.join(@home, '.agents/skills')
    @destination = File.join(@skills_dir, 'shaka')
    output, status = install
    assert_predicate status, :success?, output
    @package = package_path
    @aliases = File.join(@home, '.codex/skills')
    FileUtils.mkdir_p(@aliases)
    File.symlink(File.join(@package, 'skills/shaka'), File.join(@aliases, 'shaka'))
    File.symlink(File.join(@package, 'skills/shaka'), File.join(@skills_dir, 'shaka-pr-trial'))
  end
end
