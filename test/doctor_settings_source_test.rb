# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/doctor'

# Real Git decides the label, so staging, committing, and ignoring each give their own answer.
class DoctorSettingsSourceTest < Minitest::Test
  PATH = '.agents/shaka/config.yml'

  def setup
    @root = Dir.mktmpdir('settings-source')
    git('init', '-q')
    FileUtils.mkdir_p(File.join(@root, '.agents/shaka'))
    File.write(File.join(@root, PATH), "version: 1\n")
  end

  def teardown = FileUtils.remove_entry(@root)

  def test_a_staged_file_is_not_yet_committed
    git('add', PATH)
    assert_equal 'settings not committed yet', describe
  end

  def test_a_committed_file_is_team_settings
    git('add', PATH)
    git('-c', 'user.name=t', '-c', 'user.email=t@example.com', 'commit', '-q', '-m', 'settings')
    assert_equal 'team settings committed in this checkout', describe
  end

  def test_an_ignored_file_is_individual_settings
    File.write(File.join(@root, '.git/info/exclude'), "/.agents/shaka/\n")
    assert_equal 'individual settings kept out of Git', describe
  end

  private

  def describe = Shaka::Doctor::SettingsSource.new(@root, Shaka::Doctor::RUNNER).describe(PATH)

  def git(*)
    output, status = Open3.capture2e('git', '-C', @root, *)
    assert_predicate status, :success?, output
  end
end
