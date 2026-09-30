# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/configuration/feature_guard'

class FeatureGuardTest < Minitest::Test
  include EvidenceFixture

  def test_staged_and_tracked_changes_leave_unrelated_index_entries_untouched
    with_checkout do |root, ref|
      File.write(File.join(root, '.agents/agent-workflow.yml'), 'changed')
      File.write(File.join(root, 'feature.rb'), 'feature')
      git(root, 'add', 'feature.rb')
      before = git(root, 'ls-files', '--stage')
      assert_raises(Shaka::Error) { guard(root, ref) }
      assert_equal before, git(root, 'ls-files', '--stage')
      git(root, 'add', '.agents/agent-workflow.yml')
      assert_raises(Shaka::Error) { guard(root, ref) }
    end
  end

  def test_force_staging_and_committed_changes_are_blocked
    with_checkout do |root, ref|
      private_file(root)
      guard(root, ref)
      git(root, 'add', '-f', '.agents/shaka/secret')
      assert_raises(Shaka::Error) { guard(root, ref) }
      commit(root)
      assert_raises(Shaka::Error) { guard(root, ref) }
      assert_equal 'setup', guard(root, ref, flow: 'setup').fetch('flow')
    end
  end

  def test_rename_out_of_configuration_and_untracked_legacy_seam_are_blocked
    with_checkout do |root, ref|
      git(root, 'mv', '.agents/bin/test', 'renamed-test')
      assert_raises(Shaka::Error) { guard(root, ref) }
      assert_raises(Shaka::Error) { guard(root, ref, flow: 'other') }
    end
  end

  private

  def private_file(root)
    File.write(File.join(root, '.git/info/exclude'), "/.agents/shaka/\n")
    FileUtils.mkdir_p(File.join(root, '.agents/shaka'))
    File.write(File.join(root, '.agents/shaka/secret'), 'private')
  end

  def guard(root, base, flow: 'feature')
    Shaka::Configuration::FeatureGuard.check(root:, base:, head: git(root, 'rev-parse', 'HEAD'), flow:)
  end
end
