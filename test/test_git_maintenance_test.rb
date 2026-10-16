# frozen_string_literal: true

require_relative 'test_helper'

# Hosted validate failed when Git's background maintenance removed .git/objects/maintenance.lock
# while Dir.mktmpdir was deleting a fixture repository.
class TestGitMaintenanceTest < Minitest::Test
  def test_fixture_repositories_never_start_background_maintenance
    Dir.mktmpdir('shaka-maintenance') do |root|
      Open3.capture2e(TEST_GIT, 'init', '--quiet', root)

      assert_equal(%w[false 0], %w[maintenance.auto gc.auto].map { |key| config(root, key) })
    end
  end

  def config(root, key)
    output, = Open3.capture2e(TEST_GIT, '-C', root, 'config', '--get', key)
    output.strip
  end
end
