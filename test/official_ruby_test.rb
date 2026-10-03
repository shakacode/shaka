# frozen_string_literal: true

require_relative 'official_install_support'

class OfficialRubyTest < Minitest::Test
  include OfficialInstallSupport

  def setup
    super
    FileUtils.rm_rf(@source)
    FileUtils.cp_r(File.expand_path('../skills/shaka', __dir__), @source)
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
    official_install
    @helper = File.join(@destination, 'scripts/shaka')
  end

  def test_helper_and_verification_use_recorded_ruby_outside_the_installation
    fake = File.join(@directory, 'fake-bin')
    FileUtils.mkdir_p(fake)
    File.write(File.join(fake, 'ruby'), "#!/bin/sh\necho project-ruby >&2; exit 1\n")
    File.chmod(0o755, File.join(fake, 'ruby'))
    environment = { 'PATH' => "#{fake}:#{ENV.fetch('PATH')}", 'RUBYOPT' => '-rmissing_project_bundler' }
    output, status = Open3.capture2e(environment, @helper, 'install', '--verify', chdir: @directory)
    assert_predicate status, :success?, output
    assert_includes output, 'Verified Shaka installation'
  end

  def test_doctor_identifies_the_official_checkout
    output, status = Open3.capture2e(@helper, 'doctor', '--installation-json', chdir: @directory)
    assert_predicate status, :success?, output
    identity = JSON.parse(output)
    assert_equal 'revision', identity.fetch('source').fetch('kind')
    assert_equal git('-C', @root, 'rev-parse', 'HEAD').strip, identity.fetch('source').fetch('revision')
  end

  def test_missing_recorded_ruby_refuses_project_fallback
    File.unlink(File.join(@root, '.git/shaka-ruby'))
    output, status = Open3.capture2e(@helper, 'install', '--verify')
    refute_predicate status, :success?
    assert_includes output, 'installation Ruby is unavailable'
  end
end
