# frozen_string_literal: true

require_relative 'install_support'

module OfficialInstallSupport
  include InstallTestSupport

  def setup
    super
    @root = File.dirname(@source, 2)
    @remote = File.join(@directory, 'remote.git')
    git('init', '--bare', '-q', @remote)
    git('init', '-q', '-b', 'main', @root)
    git('-C', @root, 'remote', 'add', 'origin', @remote)
    commit_source
    git('-C', @root, 'push', '-qu', 'origin', 'main')
  end

  private

  def official_install
    output, status = invoke('--directory', @root, '--repository', @remote, '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
  end

  def invoke(*)
    Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, @installer, *)
  end

  def commit_source
    git('-C', @root, 'add', '.')
    git('-C', @root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'fixture')
  end

  def assert_refusal(message)
    output, status = invoke('--update')
    refute_predicate status, :success?
    assert_includes output, message
  end
end
