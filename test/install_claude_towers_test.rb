# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'rbconfig'

class InstallClaudeTowersTest < Minitest::Test
  SKILLS = { 'shaka' => 'shaka source', 'rct' => 'rct source',
             'mct-claude' => 'mct source', 'rct-claude' => 'rct-claude source' }.freeze

  def setup
    @directory = Dir.mktmpdir('workflows-claude-towers')
    @installer = File.join(@directory, 'source', 'bin', 'install')
    @skills_dir = File.join(@directory, 'isolated profile', 'skills')
    FileUtils.mkdir_p(File.dirname(@installer))
    FileUtils.cp(File.expand_path('../bin/install', __dir__), @installer)
    write_skills
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_installs_both_tower_skills_beside_shaka
    output, status = install('--with-claude-towers')

    assert_predicate status, :success?, output
    %w[shaka mct-claude rct-claude].each { |name| assert_linked(name) }
  end

  # The Codex tower drives native tools Claude Code does not have, so one flag never implies the other.
  def test_claude_towers_do_not_install_the_codex_repository_tower
    assert_predicate install('--with-claude-towers').last, :success?
    refute_path_exists destination('rct')
  end

  def test_codex_tower_does_not_install_the_claude_towers
    assert_predicate install('--with-rct').last, :success?
    %w[mct-claude rct-claude].each { |name| refute_path_exists destination(name), name }
  end

  def test_default_install_omits_every_tower
    assert_predicate install.last, :success?
    %w[rct mct-claude rct-claude].each { |name| refute_path_exists destination(name), name }
  end

  # A partial install would leave one tower skill linked and the other silently missing.
  def test_preflight_refuses_before_linking_any_skill
    FileUtils.mkdir_p(destination('mct-claude'))
    marker = File.join(destination('mct-claude'), 'keep')
    File.write(marker, 'user content')

    refute_predicate install('--with-claude-towers').last, :success?
    refute_path_exists destination('shaka')
    assert_equal 'user content', File.read(marker)
  end

  private

  def assert_linked(name)
    assert File.symlink?(destination(name)), name
    assert_equal File.realpath(source(name)), File.readlink(destination(name))
    assert_equal SKILLS.fetch(name), File.read(File.join(destination(name), 'SKILL.md'))
  end

  def write_skills
    SKILLS.each do |name, content|
      FileUtils.mkdir_p(source(name))
      File.write(File.join(source(name), 'SKILL.md'), content)
    end
  end

  def source(name)
    File.join(@directory, 'source', 'skills', name)
  end

  def destination(name)
    File.join(@skills_dir, name)
  end

  def install(*flags)
    Open3.capture2e(RbConfig.ruby, @installer, '--skills-dir', @skills_dir, *flags)
  end
end
