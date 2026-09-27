# frozen_string_literal: true

require_relative 'install_support'
require 'shaka/install/tree'

class InstallRecoveryTest < Minitest::Test
  include InstallTestSupport

  def test_upgrade_refuses_to_leave_an_omitted_managed_skill_on_an_old_package
    install!
    previous = File.readlink(@destination)
    File.write(File.join(@source, 'SKILL.md'), 'version two')
    output, status = run_installer('--skills-dir', @skills_dir)

    refute_predicate status, :success?
    assert_includes output, 'rct was omitted'
    assert_equal previous, File.readlink(@destination)
  end

  def test_rollback_refuses_to_mix_a_shaka_only_package_with_a_linked_tower
    output, status = run_installer('--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
    shaka_only = package_identity.fetch('package_id')
    output, status = install
    assert_predicate status, :success?, output
    output, status = run_installer('--skills-dir', @skills_dir, '--rollback', shaka_only)

    refute_predicate status, :success?
    assert_includes output, 'rct was omitted'
  end

  def test_dangling_managed_link_can_be_reinstalled
    install!
    FileUtils.remove_entry(package_path)
    output, status = install

    assert_predicate status, :success?, output
    assert_equal 'version one', File.read(File.join(@destination, 'SKILL.md'))
  end

  def test_managed_directory_can_be_chosen_explicitly
    managed = File.join(@directory, 'durable packages')
    output, status = run_installer('--skills-dir', @skills_dir, '--managed-dir', managed)

    assert_predicate status, :success?, output
    assert File.readlink(@destination).start_with?(File.realpath(managed))
  end

  def test_refuses_a_skills_directory_reached_through_a_symlink_into_source
    alias_path = File.join(@directory, 'source-alias')
    File.symlink(File.join(@directory, 'source'), alias_path)
    output, status = run_installer('--skills-dir', File.join(alias_path, 'host-skills'))

    refute_predicate status, :success?
    assert_includes output, 'overlaps source checkout'
  end

  def test_checkout_reference_check_requires_a_path_separator
    path = File.join(@source, 'example.md')
    tree = Shaka::Install::Tree.new(['shaka'])
    File.write(path, 'The string /srcplus is unrelated.')
    tree.reject_checkout_references(File.join(@directory, 'source'), '/src')
    File.write(path, 'A helper at /src/bin/install is unsafe.')

    assert_raises(ArgumentError) { tree.reject_checkout_references(File.join(@directory, 'source'), '/src') }
  end

  private

  def install!
    output, status = install
    assert_predicate status, :success?, output
  end
end
