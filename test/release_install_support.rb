# frozen_string_literal: true

require_relative 'official_install_support'

module ReleaseInstallSupport
  include OfficialInstallSupport

  def setup
    super
    @release = git('-C', @root, 'rev-parse', 'HEAD').strip
    git('-C', @root, 'tag', 'v0.1.0.pre.1')
    git('-C', @root, 'push', '-q', 'origin', 'refs/tags/v0.1.0.pre.1')
    File.write(File.join(@source, 'SKILL.md'), 'unreleased changes')
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
    @installed = File.join(@directory, 'released')
  end

  private

  def install_release(version = '0.1.0.pre.1')
    invoke('--directory', @installed, '--repository', @remote, '--release', version, '--skills-dir', @skills_dir)
  end
end
