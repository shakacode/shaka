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

  # Where the source checkout, each host's skills folder, and the settings are; the source is not configuration.
  def assert_location_summary(output, source, folders)
    revision = git('-C', source, 'rev-parse', '--short=7', 'HEAD').strip
    assert_includes output, "Source checkout: #{source} at #{revision} (Shaka source, not configuration)\n" \
                            "Skills folders: #{folders.join(', ')}\n" \
                            "Settings: each project's .agents/shaka/ and ~/.agents/trusted-github-actors.yml\n"
  end

  # A symlink with mode 0777, as Linux reports every symlink; macOS can set that mode, Linux cannot change it.
  def loose_symlink(target, link)
    File.symlink(target, link)
    begin
      File.lchmod(0o777, link)
    rescue NotImplementedError, Errno::ENOTSUP
      nil
    end
  end

  def assert_refusal(message)
    output, status = invoke('--update')
    refute_predicate status, :success?
    assert_includes output, message
  end
end
