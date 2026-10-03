# frozen_string_literal: true

require_relative 'official_install_support'
require 'shellwords'

class OfficialAuthenticationTest < Minitest::Test
  include OfficialInstallSupport

  def test_clone_and_fetch_preserve_ssh_authentication_without_repository_redirects
    prepare_authentication
    invoke_authenticated('--repository', 'ssh://fixture/source', '--skills-dir', @skills_dir)
    File.write(File.join(@source, 'SKILL.md'), 'authenticated update')
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
    invoke_authenticated('--update')
    assert_equal 'authenticated update', File.read(File.join(@destination, 'SKILL.md'))
  end

  private

  def prepare_authentication
    ssh = File.join(@directory, 'fixture-ssh')
    File.write(ssh, "#!/bin/sh\nexec git-upload-pack #{Shellwords.escape(@remote)}\n")
    File.chmod(0o755, ssh)
    @environment = { 'HOME' => @home, 'GIT_SSH_COMMAND' => Shellwords.escape(ssh),
                     'GIT_SSH_VARIANT' => 'ssh', 'GIT_DIR' => '/missing/repository', 'GIT_TERMINAL_PROMPT' => '0' }
  end

  def invoke_authenticated(*)
    installed = File.join(@directory, 'installation')
    output, status = Open3.capture2e(@environment, RbConfig.ruby, @installer, '--directory', installed, *)
    assert_predicate status, :success?, output
  end
end
