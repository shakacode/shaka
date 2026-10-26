# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/install/direct_source'
require_relative '../skills/shaka/lib/shaka/seam'

# On Windows, install and seam upgrade start Shaka's helper through Ruby, never the sh launcher.
# Each fixture launcher exits 1 silently, so a pass or a helper message proves it never ran.
class WindowsHelperStartTest < Minitest::Test
  SKILL = File.expand_path('../skills/shaka', __dir__)

  def setup
    @windows = Shaka::ExecutableFile.method(:windows?)
    Shaka::ExecutableFile.define_singleton_method(:windows?) { true }
  end

  def teardown
    Shaka::ExecutableFile.define_singleton_method(:windows?, @windows)
  end

  def test_install_verifies_the_incoming_helper_without_its_launcher
    with_unrunnable_launcher do |root, _launcher|
      Shaka::Install::DirectSource.new(root, ['shaka'], nil).send(:verify_helper)
    end
  end

  def test_seam_upgrade_checks_the_candidate_without_the_launcher
    with_unrunnable_launcher do |root, launcher|
      apply = Object.new.extend(Shaka::Seam::MigrationApply)
      apply.define_singleton_method(:root) { root }
      apply.define_singleton_method(:shaka_command) { launcher }
      # The candidate has no settings, so the check fails with the helper's own message.
      error = assert_raises(Shaka::Error) { apply.send(:verify_candidate, []) }

      assert_match(/candidate seam check failed: \S/, error.message)
    end
  end

  private

  def with_unrunnable_launcher
    Dir.mktmpdir('shaka-windows-helper') do |root|
      scripts = File.join(root, 'skills/shaka/scripts')
      FileUtils.mkdir_p(scripts)
      FileUtils.cp(File.join(SKILL, 'scripts/shaka.rb'), scripts)
      File.symlink(File.join(SKILL, 'lib'), File.join(root, 'skills/shaka/lib'))
      launcher = File.join(scripts, 'shaka')
      File.write(launcher, "#!/bin/sh\nexit 1\n")
      File.chmod(0o755, launcher)
      yield root, launcher
    end
  end
end
