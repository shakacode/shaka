# frozen_string_literal: true

require_relative 'official_install_support'

class OfficialInstallIgnoreTest < Minitest::Test
  include OfficialInstallSupport

  def test_verify_and_update_skip_gitignored_files_under_the_skill
    official_install
    File.write(File.join(@root, '.git/info/exclude'), ".DS_Store\n")
    File.write(File.join(@root, 'skills/shaka/.DS_Store'), '')
    assert_empty git('-C', @root, 'status', '--porcelain', '--untracked-files=all')

    output, status = invoke('--verify')
    assert_predicate status, :success?, output
    output, status = invoke('--update')
    assert_predicate status, :success?, output
    assert_path_exists File.join(@root, 'skills/shaka/.DS_Store')
  end
end
