# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../skills/shaka/lib/shaka/install/settings_location'

# The take-over names --skills-dir only for a folder that is not a host's, however HOME was spelled.
class SettingsLocationCustomFolderTest < Minitest::Test
  def test_a_host_folder_recorded_through_a_link_to_home_is_not_custom
    Dir.mktmpdir do |directory|
      home = File.join(directory, 'home')
      FileUtils.mkdir_p(File.join(home, '.claude/skills'))
      File.symlink(home, File.join(directory, 'alias'))
      record = { 'targets' => [{ 'directory' => File.join(directory, 'alias/.claude/skills') }] }
      assert_empty Shaka::Install::SettingsLocation.custom_folder(record, home)
    end
  end

  def test_a_folder_outside_the_hosts_is_named
    Dir.mktmpdir do |directory|
      custom = File.join(directory, 'skills')
      record = { 'targets' => [{ 'directory' => custom }] }
      assert_equal ['--skills-dir', custom], Shaka::Install::SettingsLocation.custom_folder(record, directory)
    end
  end
end
