# frozen_string_literal: true

require_relative 'official_install_support'

# --skills-dir alone once made a managed copy; it now selects a folder for the official checkout.
class OfficialSkillsFolderTest < Minitest::Test
  include OfficialInstallSupport

  def test_a_custom_skills_folder_alone_links_the_default_checkout
    output, status = invoke('--repository', @remote, '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
    source = File.realpath(File.join(@home, '.local/share/shaka/source'))
    assert_equal File.join(source, 'skills/shaka'), File.readlink(@destination)
    refute_path_exists File.join(@home, '.local/share/shaka/installs')
    output, status = invoke('--verify')
    assert_predicate status, :success?, output
  end
end
