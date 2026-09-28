# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/workflow_version'

class WorkflowVersionTest < Minitest::Test
  VERSION = Shaka::VERSION
  SHA = 'a' * 40

  def source(kind, revision: nil, base: nil)
    { 'version' => VERSION, 'source' => { 'kind' => kind, 'revision' => revision, 'base_revision' => base } }
  end

  def test_an_exact_installed_revision_names_its_commit
    assert_equal "#{VERSION}-#{SHA}", Shaka::WorkflowVersion.current(identity: source('revision', revision: SHA))
  end

  def test_a_development_installation_names_its_base_and_marks_it_modified
    assert_equal "#{VERSION}-#{SHA}-modified",
                 Shaka::WorkflowVersion.current(identity: source('development', base: SHA))
    assert_equal "#{VERSION}-modified", Shaka::WorkflowVersion.current(identity: source('development'))
  end

  def test_a_direct_checkout_names_its_head_commit
    in_checkout do |root, head|
      assert_equal "#{VERSION}-#{head}", Shaka::WorkflowVersion.current(identity: source('uninstalled'), root:)
    end
  end

  def test_a_direct_checkout_with_local_skill_changes_is_marked_modified
    in_checkout do |root, head|
      File.write(File.join(root, 'skills/shaka/SKILL.md'), "changed\n")
      assert_equal "#{VERSION}-#{head}-modified",
                   Shaka::WorkflowVersion.current(identity: source('uninstalled'), root:)
    end
  end

  def test_changes_outside_the_skill_do_not_mark_a_checkout_modified
    in_checkout do |root, head|
      File.write(File.join(root, 'notes.txt'), "scratch\n")
      assert_equal "#{VERSION}-#{head}", Shaka::WorkflowVersion.current(identity: source('uninstalled'), root:)
    end
  end

  def test_an_unidentifiable_copy_says_the_commit_is_unknown
    Dir.mktmpdir do |root|
      assert_equal "#{VERSION}-unknown", Shaka::WorkflowVersion.current(identity: source('uninstalled'), root:)
    end
  end

  def test_the_result_fits_the_public_provenance_allowlist
    value = Shaka::WorkflowVersion.current(identity: source('development', base: SHA))
    assert_match(/\A[A-Za-z0-9][A-Za-z0-9._:-]{0,79}\z/, value)
  end

  private

  def in_checkout
    Dir.mktmpdir do |dir|
      root = File.realpath(dir)
      FileUtils.mkdir_p(File.join(root, 'skills/shaka'))
      File.write(File.join(root, 'skills/shaka/SKILL.md'), "skill\n")
      git(root, 'init', '-q')
      git(root, 'add', '.')
      git(root, '-c', 'user.name=t', '-c', 'user.email=t@example.com', 'commit', '-q', '-m', 'init')
      yield root, git(root, 'rev-parse', 'HEAD').strip
    end
  end

  def git(root, *)
    output, status = Open3.capture2(TEST_GIT, '-C', root, *)
    assert status.success?
    output
  end
end
