# frozen_string_literal: true

require_relative 'install_refusal_support'

class OfficialSkillBackupTest < Minitest::Test
  include InstallRefusalSupport

  def test_existing_directory_is_moved_outside_the_skills_directory
    FileUtils.mkdir_p(@destination)
    File.write(File.join(@destination, 'SKILL.md'), 'old skill')
    run_next(install_conflict)
    assert_empty Dir.children(@skills_dir)
    official_install
    assert_equal [@destination], Dir.glob("#{@skills_dir}/*")
    assert_equal ['old skill'], skill_backups.map { |backup| File.read("#{backup}/SKILL.md") }.sort
  end

  def test_reusing_the_move_command_preserves_both_old_symlinks
    first = File.join(@skills_dir, '.first old skill')
    FileUtils.mkdir_p(first)
    File.symlink('.first old skill', @destination)
    output = install_conflict
    run_next(output)
    File.symlink(@rct_source, @destination)
    run_next(output)
    assert_equal [first, @rct_source].map { |path| File.realpath(path) }.sort,
                 skill_backups.map { |backup| File.realpath(backup) }.sort
  end

  def test_existing_file_is_backed_up_in_home_when_skills_parent_is_read_only
    skip 'Requires a user subject to directory permissions' if Process.euid.zero?

    FileUtils.mkdir_p([@skills_dir, @home])
    File.write(@destination, 'old skill')
    with_read_only_skills_parent { run_next(install_conflict) }
    assert_empty Dir.children(@skills_dir)
    assert_equal 'old skill', File.read(skill_backups("#{@home}/skills").fetch(0))
  end

  private

  def install_conflict
    output, status = invoke('--directory', @root, '--repository', @remote, '--skills-dir', @skills_dir)
    refute_predicate status, :success?
    assert_includes output, "Refusing existing destination: #{@destination}"
    output
  end

  def skill_backups(skills_dir = @skills_dir) = Dir.glob("#{skills_dir}.before-shaka.*/shaka")

  def with_read_only_skills_parent
    parent = File.dirname(@skills_dir)
    File.chmod(0o555, parent)
    yield
  ensure
    File.chmod(0o755, parent)
  end
end
