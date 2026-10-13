# frozen_string_literal: true

require_relative 'official_install_support'
require 'yaml'

class InstallCodexTowersTest < Minitest::Test
  include OfficialInstallSupport

  def setup
    super
    @mct_source = File.join(@root, 'skills/mct')
    FileUtils.cp_r(File.expand_path('../skills/mct', __dir__), @mct_source)
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
  end

  def test_codex_discovery_and_update_retain_selected_companions
    installed, skills = install_codex_towers
    assert_discoverable_master(skills)
    update_source
    output, status = invoke('--directory', installed, '--update')
    assert_predicate status, :success?, output
    assert_equal 'rct version two', File.read(File.join(skills, 'rct/SKILL.md'))
    assert_includes File.read(File.join(skills, 'mct/SKILL.md')), 'Updated fixture.'
    assert_discoverable_master(skills)
    assert_predicate invoke('--directory', installed, '--verify').last, :success?
  end

  def test_adding_master_and_reinstalling_preserves_repository_tower
    official_install
    assert_predicate invoke('--with-rct').last, :success?
    output, status = invoke('--with-mct')
    assert_predicate status, :success?, output
    output, status = invoke
    assert_predicate status, :success?, output
    %w[shaka rct mct].each { |name| assert File.symlink?(File.join(@skills_dir, name)), name }
    assert_discoverable_master(@skills_dir)
  end

  def test_maintenance_cannot_change_master_selection
    official_install
    %w[--update --verify].each do |action|
      output, status = invoke(action, '--with-mct')
      refute_predicate status, :success?
      assert_includes output, 'Use bin/install to change installation selections'
    end
    refute_path_exists File.join(@skills_dir, 'mct')
  end

  private

  def install_codex_towers
    installed = File.join(@directory, 'installation')
    output, status = invoke('--directory', installed, '--repository', @remote,
                            '--agent', 'codex', '--with-rct', '--with-mct')
    assert_predicate status, :success?, output
    skills = File.join(@home, '.agents/skills')
    assert_equal %w[mct rct shaka], Dir.children(skills).reject { |name| name.start_with?('.') }.sort
    [installed, skills]
  end

  def update_source
    File.write(File.join(@rct_source, 'SKILL.md'), 'rct version two')
    File.open(File.join(@mct_source, 'SKILL.md'), 'a') { |file| file.puts 'Updated fixture.' }
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
  end

  def assert_discoverable_master(skills)
    path = File.join(skills, 'mct/SKILL.md')
    assert File.symlink?(File.join(skills, 'mct'))
    metadata = YAML.safe_load(File.read(path).split('---', 3)[1])
    assert_equal 'mct', metadata.fetch('name')
    refute_empty metadata.fetch('description')
  end
end
