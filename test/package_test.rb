# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'json'
require 'rbconfig'
require 'bundler'
require 'rubygems/package'

class PackageTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def setup
    @directory = Dir.mktmpdir('workflows-package')
    @home = File.join(@directory, 'gem home')
    @environment = { 'GEM_HOME' => @home, 'GEM_PATH' => @home }
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_built_gem_runs_and_installs_its_skill_without_the_source_checkout
    archive = File.join(@directory, 'pilot.gem')
    run_gem('build', 'shaka.gemspec', '--output', archive, chdir: ROOT)
    run_gem('install', '--local', '--no-document', archive)
    check_commands
    source = install_skill
    %w[shaka rct mct-claude].each { |name| File.unlink(File.join(@directory, 'pilot skills', name)) }
    run_gem('uninstall', 'shaka', '--all', '--executables', '--ignore-dependencies')
    refute File.exist?(File.join(@home, 'bin', 'shaka'))
    refute File.exist?(source)
  end

  def test_built_gem_distributes_the_declared_license
    archive = File.join(@directory, 'licensed.gem')
    run_gem('build', 'shaka.gemspec', '--output', archive, chdir: ROOT)
    package = Gem::Package.new(archive)
    assert_equal ['MIT'], package.spec.licenses
    package.extract_files(File.join(@directory, 'unpacked'))
    license = File.join(@directory, 'unpacked', 'LICENSE')
    assert File.file?(license), 'The distributed gem must include its license'
    assert_equal File.read(File.join(ROOT, 'LICENSE')), File.read(license)
  end

  def test_installed_gem_screens_public_comments_for_a_non_skill_consumer
    install_gem
    result = run_public_comments_consumer
    assert_equal([%w[maintainer writer]], result['issue_comments'].map { |row| row.values_at('author', 'trust') })
    assert_equal(%w[stranger helper[bot]], result['excluded_interactions'].map { |row| row['author'] })
    refute_includes JSON.generate(result['excluded_interactions']), 'comment 2'
  end

  def test_built_gem_packages_no_trusted_actor_list
    archive = File.join(@directory, 'trust.gem')
    run_gem('build', 'shaka.gemspec', '--output', archive, chdir: ROOT)
    assert_empty Gem::Package.new(archive).spec.files.grep(%r{(?:\A|/)trusted-github-actors\.ya?ml\z})
  end

  private

  def run_public_comments_consumer
    consumer = File.join(ROOT, 'test', 'fixtures', 'public_comments_consumer.rb')
    result = JSON.parse(run_command(consumer, File.join(@directory, 'absent-machine-config.yml')))
    loaded = result.fetch('loaded_from')
    refute_empty loaded
    assert(loaded.all? { |path| path.start_with?(File.realpath(@home)) }, loaded)
    assert_empty(loaded.grep(%r{/(?:github|work|merge)\.rb\z|/scripts/shaka\z}), loaded)
    result
  end

  def install_gem
    archive = File.join(@directory, 'consumer.gem')
    run_gem('build', 'shaka.gemspec', '--output', archive, chdir: ROOT)
    run_gem('install', '--local', '--no-document', archive)
  end

  def check_commands
    assert_includes run_executable('shaka', '--help'), 'Usage: shaka'
    workflow = run_executable('shaka', 'workflow')
    assert_includes workflow, '## 1. Intake'
    assert_includes workflow, '## 7. Finish'
    assert_match(/\]\(<[^>]+gem home[^>]+>\)/, workflow)
  end

  def check_public_skills(skills, source)
    check_shaka_skill(File.realpath(File.join(skills, 'shaka')), source)
    %w[rct mct-claude].each do |name|
      tower = File.realpath(File.join(skills, name))
      assert File.file?(File.join(tower, 'SKILL.md')), name
      assert_equal File.dirname(source), File.dirname(tower)
    end
  end

  def check_shaka_skill(shaka, source)
    assert File.file?(File.join(shaka, 'SKILL.md'))
    assert File.file?(File.join(shaka, 'config', 'workflow.yml'))
    assert_equal source, shaka
  end

  def install_skill
    skills = File.join(@directory, 'pilot skills')
    run_executable('shaka-install', '--skills-dir', skills, '--with-rct', '--with-claude-towers')
    source = File.realpath(File.join(skills, 'shaka'))
    assert source.start_with?("#{File.realpath(@home)}/gems/"), source
    check_public_skills(skills, source)
    assert File.file?(File.join(source, 'SKILL.md'))
    assert File.file?(File.join(source, 'scripts', 'shaka'))
    source
  end

  def run_executable(name, *)
    run_command(File.join(@home, 'bin', name), *)
  end

  def run_gem(*, chdir: @directory)
    run_command('-S', 'gem', *, chdir: chdir)
  end

  def run_command(*, chdir: @directory)
    output, status = Bundler.with_unbundled_env do
      Open3.capture2e(@environment, RbConfig.ruby, *, chdir: chdir)
    end
    assert status.success?, output
    output
  end
end
