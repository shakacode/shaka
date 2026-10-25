# frozen_string_literal: true

require_relative 'package_test_helpers'

class PackageReleaseInstallTest < Minitest::Test
  include PackageTestHelpers

  def test_gem_installer_selects_its_own_release_instead_of_newer_main
    install_gem
    prepare_release
    prepare_newer_main
    @skills = File.join(@directory, 'skills')
    run_command(File.join(@home, 'bin/shaka-install'), '--skills-dir', @skills)
    assert_installed_release
    assert_development_override
  end

  private

  def prepare_release
    @source = File.join(@directory, 'source')
    gem = Gem::Package.new(File.join(@directory, 'consumer.gem'))
    gem.extract_files(@source)
    git('init', '-q', '-b', 'main', @source)
    commit
    @version = gem.spec.version.to_s
    git('-C', @source, 'tag', "v#{@version}")
    @released = File.read(File.join(@source, 'skills/shaka/SKILL.md'))
  end

  def prepare_newer_main
    File.write(File.join(@source, 'skills/shaka/SKILL.md'), 'Unreleased development workflow')
    commit
    remote = File.join(@directory, 'remote.git')
    git('clone', '-q', '--bare', @source, remote)
    config = File.join(@directory, 'gitconfig')
    File.write(config, "[url \"#{remote}\"]\n  insteadOf = https://github.com/shakacode/shaka.git\n")
    @environment['GIT_CONFIG_GLOBAL'] = config
  end

  def assert_installed_release
    assert_equal @released, File.read(File.join(@skills, 'shaka/SKILL.md'))
    checkout = File.dirname(File.realpath(File.join(@skills, 'shaka')), 2)
    record = JSON.parse(File.read(File.join(checkout, '.git/shaka-install.json')))
    assert_equal @version, record.fetch('release')
    assert_nil record.fetch('branch')
    assert_pinned_update(checkout)
  end

  def assert_pinned_update(checkout)
    output, status = Open3.capture2e(@environment, File.join(checkout, 'skills/shaka/scripts/shaka'), 'update-check')
    assert_predicate status, :success?, output
    assert_equal 'pinned_release', JSON.parse(output).fetch('reason')
    run_command(File.join(checkout, 'bin/install'), '--update')
  end

  def assert_development_override
    development = File.join(@directory, 'development')
    run_command(File.join(@home, 'bin/shaka-install'), '--directory', development, '--branch', 'main',
                '--take-over', '--skills-dir', @skills)
    run_command(File.join(@home, 'bin/shaka-install'), '--directory', development)
    record = JSON.parse(File.read(File.join(development, '.git/shaka-install.json')))
    assert_equal 'main', record.fetch('branch')
    refute record.key?('release')
  end

  def commit
    git('-C', @source, 'add', '.')
    git('-C', @source, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'package fixture')
  end

  def git(*)
    output, status = Open3.capture2e('git', *)
    assert_predicate status, :success?, output
    output
  end
end
