# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/seam_upgrade_fixture'

class SeamUpgradePreviewTest < Minitest::Test
  include SeamUpgradeFixture

  def test_preview_is_read_only_and_classifies_references
    with_repository do |root|
      add_references(root)
      before = [git!(root, 'status', '--porcelain=v1', '-z'), git!(root, 'ls-files', '--stage')]
      preview = report(root)
      assert_equal before, [git!(root, 'status', '--porcelain=v1', '-z'), git!(root, 'ls-files', '--stage')]
      assert_preview(preview)
    end
  end

  def add_references(root)
    FileUtils.mkdir_p(File.join(root, '.github/workflows'))
    FileUtils.mkdir_p(File.join(root, 'docs'))
    File.write(File.join(root, '.github/workflows/ci.yml'), 'run: .agents/bin/test')
    File.write(File.join(root, 'docs/migration.md'), 'Previously .agents/bin/test')
    commit_fixture(root, 'references')
  end

  def assert_preview(preview)
    assert_equal 'ready', preview.fetch('status')
    assert_move_and_repairs(preview)
    assert_reference_kinds(preview)
  end

  def assert_move_and_repairs(preview)
    moves = preview.fetch('moves').to_h { |item| [item.fetch('from'), item.fetch('to')] }
    assert_equal '.agents/shaka/config.yml', moves.fetch('.agents/agent-workflow.yml')
    assert_includes preview.fetch('repairs').map { |item| item.fetch('kind') }, 'generated shell root discovery'
  end

  def assert_reference_kinds(preview)
    kinds = preview.fetch('references').to_h { |item| [item.fetch('path'), item.fetch('kind')] }
    assert_equal 'tracked CI', kinds.fetch('.github/workflows/ci.yml')
    assert_equal 'historical', kinds.fetch('docs/migration.md')
  end

  def test_unrelated_edits_are_allowed_and_overlapping_edits_block
    with_repository do |root|
      File.write(File.join(root, 'notes.txt'), 'unrelated')
      assert_equal 'ready', report(root).fetch('status')
      File.open(File.join(root, '.agents/bin/setup'), 'a') { |file| file.write("# edited\n") }
      assert_blocker(root, 'overlapping checkout edit')
      assert_equal 'unrelated', File.read(File.join(root, 'notes.txt'))
    end
  end

  def test_existing_private_destination_blocks_without_overwrite
    with_repository do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/shaka'))
      File.write(File.join(root, '.agents/shaka/config.yml'), 'private')
      assert_blocker(root, 'partial migration')
      assert_equal 'private', File.read(File.join(root, '.agents/shaka/config.yml'))
    end
  end

  def test_ambiguous_custom_root_blocks
    with_repository do |root|
      write_wrapper(root, 'setup', "#!/bin/sh\nroot=$(custom_dirname \"$0\")/../..\nexit 0\n")
      commit_fixture(root, 'ambiguous')
      assert_blocker(root, 'ambiguous repository-root')
    end
  end

  def assert_blocker(root, phrase)
    preview = report(root)
    assert_equal 'blocked', preview.fetch('status')
    assert(preview.fetch('blockers').any? { |message| message.include?(phrase) })
  end
end

class SeamUpgradeApplyTest < Minitest::Test
  include SeamUpgradeFixture

  def test_apply_preserves_arguments_working_directory_exit_status_and_policy_source
    with_repository do |root, parent|
      add_pointer(root)
      before = probe_results(root, '.agents/bin/setup', parent)
      assert_equal 'applied', report(root, '--apply').fetch('status')
      assert_equal before, probe_results(root, '.agents/shaka/bin/setup', parent)
      assert_moved_layout(root)
      assert_policy_sources(root)
    end
  end

  def add_pointer(root)
    File.write(File.join(root, '.agents/shaka.md'), 'Run .agents/bin/validate and read .agents/agent-workflow.yml')
    commit_fixture(root, 'pointer')
  end

  def probe_results(root, command, parent)
    path = File.join(root, command)
    [%w[one two], %w[fail]].map do |arguments|
      output, _error, status = Open3.capture3(path, *arguments, chdir: parent)
      [normalized_output(output), status.exitstatus]
    end
  end

  def assert_moved_layout(root)
    assert_equal 'version: 1', File.read(File.join(root, '.agents/shaka/config.yml')).lines.first.strip
    assert File.executable?(File.join(root, '.agents/shaka/bin/setup'))
    assert_equal 'Run .agents/shaka/bin/validate and read .agents/shaka/config.yml',
                 File.read(File.join(root, '.agents/shaka.md'))
    assert_equal 'already_upgraded', report(root).fetch('status')
  end

  def assert_policy_sources(root)
    sha = git!(root, 'rev-parse', 'HEAD').strip
    output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--root', root, '--ref', sha)
    assert_predicate status, :success?, error
    paths = JSON.parse(output).fetch('paths')
    assert_equal '.agents/agent-workflow.yml', paths.fetch('policy_configuration')
    assert_equal '.agents/shaka/config.yml', paths.fetch('candidate_configuration')
  end

  def test_linked_worktree_uses_its_own_root
    with_repository do |root, parent|
      linked = File.join(parent, 'linked')
      git!(root, 'worktree', 'add', '-q', '-b', 'fixture-linked', linked)
      report(linked, '--apply')
      output, error, status = Open3.capture3(File.join(linked, '.agents/shaka/bin/setup'), 'linked', chdir: parent)
      assert_predicate status, :success?, error
      assert_equal "#{File.realpath(linked)}\nlinked\n", output
    end
  end

  def test_safe_relative_symlink_keeps_its_target
    with_repository do |root|
      path = File.join(root, '.agents/bin/validate')
      File.delete(path)
      File.symlink('../../bin/probe', path)
      commit_fixture(root, 'link')
      assert_equal '../../../bin/probe', report(root).fetch('symlinks').first.fetch('new_target')
      report(root, '--apply')
      assert_equal '../../../bin/probe', File.readlink(File.join(root, '.agents/shaka/bin/validate'))
    end
  end

  def test_external_symlink_is_refused
    with_repository do |root, parent|
      external = File.join(parent, 'outside')
      File.write(external, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, external)
      path = File.join(root, '.agents/bin/validate')
      File.delete(path)
      File.symlink(external, path)
      assert_equal 'blocked', report(root).fetch('status')
    end
  end

  def test_custom_shell_root_is_repaired
    with_repository do |root|
      write_wrapper(root, 'setup', custom_shell_wrapper)
      commit_fixture(root, 'custom')
      repairs = report(root).fetch('repairs')
      assert_includes repairs.map { |item| item.fetch('kind') }, 'custom shell root discovery'
    end
  end

  def custom_shell_wrapper
    "#!/bin/sh\nset -eu\nroot=$(dirname \"$0\")/../..\ncd \"$root\"\nexec \"$root/bin/probe\" \"$@\"\n"
  end
end

class SeamUpgradeRecoveryTest < Minitest::Test
  include SeamUpgradeFixture

  def test_interrupted_apply_restores_known_files_and_keeps_unrelated_edits
    with_repository do |root|
      journal = write_journal(root, plan_for(root))
      create_moved_config(root, journal)
      File.write(File.join(root, 'notes.txt'), 'keep this')
      assert_equal 'recovery_required', report(root).fetch('status')
      assert_equal 'restored', report(root, '--recover').fetch('status')
      assert_equal 'keep this', File.read(File.join(root, 'notes.txt'))
      assert_legacy_root_restored(root)
    end
  end

  def create_moved_config(root, journal)
    moved = File.join(root, '.agents/shaka/config.yml')
    FileUtils.mkdir_p(File.dirname(moved))
    File.binwrite(moved, journal.fetch('desired').fetch('.agents/shaka/config.yml').fetch('data').unpack1('m0'))
  end

  def test_recovery_preserves_later_user_edit
    with_repository do |root|
      write_journal(root, plan_for(root))
      File.write(File.join(root, '.agents/bin/setup'), 'later user edit')
      _output, error, status = upgrade(root, '--recover')
      refute_predicate status, :success?
      assert_includes error, 'changed after interruption'
      assert_equal 'later user edit', File.read(File.join(root, '.agents/bin/setup'))
    end
  end

  def test_ordinary_failure_rolls_back
    with_repository do |root|
      File.write(File.join(root, 'notes.txt'), 'untouched')
      error = assert_raises(Shaka::Error) { failing_upgrader.new(['--root', root, '--apply']).run }
      assert_includes error.message, 'restored'
      assert_equal 'untouched', File.read(File.join(root, 'notes.txt'))
      assert_legacy_root_restored(root)
      refute_path_exists File.join(root, Shaka::Seam::Upgrader::JOURNAL)
    end
  end

  def failing_upgrader
    Class.new(Shaka::Seam::Upgrader) do
      private

      def write_state(relative, state)
        @writes = (@writes || 0) + 1
        raise Errno::EIO, 'injected failure' if @writes == 2

        super
      end
    end
  end

  def test_permission_denial_then_retry
    with_repository do |root|
      directory = File.join(root, '.agents')
      File.chmod(0o555, directory)
      assert_permission_denied(root)
    ensure
      File.chmod(0o755, directory) if directory && File.exist?(directory)
      assert_equal 'applied', report(root, '--apply').fetch('status') if root
    end
  end

  def assert_permission_denied(root)
    _output, error, status = upgrade(root, '--apply')
    refute_predicate status, :success?
    assert_includes error, 'Permission denied'
    assert File.file?(File.join(root, '.agents/agent-workflow.yml'))
    refute_path_exists File.join(root, Shaka::Seam::Upgrader::JOURNAL)
  end

  def assert_legacy_root_restored(root)
    assert File.file?(File.join(root, '.agents/agent-workflow.yml'))
    refute_path_exists File.join(root, '.agents/shaka/config.yml')
  end
end

class SeamUpgradeVariantsTest < Minitest::Test
  include SeamUpgradeFixture

  def test_optional_commands_move_and_unrelated_tool_stays
    with_repository do |root|
      add_optional_commands(root)
      moves = report(root).fetch('moves').map { |item| item.fetch('from') }
      assert_includes moves, '.agents/bin/trigger-hosted-ci'
      report(root, '--apply')
      assert_optional_files(root)
    end
  end

  def add_optional_commands(root)
    write_wrapper(root, 'validate-local')
    write_wrapper(root, 'trigger-hosted-ci')
    File.write(File.join(root, '.agents/bin/formatter'), "#!/bin/sh\nexit 0\n")
    commit_fixture(root, 'optional')
  end

  def assert_optional_files(root)
    assert File.file?(File.join(root, '.agents/shaka/bin/validate-local'))
    assert File.file?(File.join(root, '.agents/bin/formatter'))
  end

  def test_existing_new_command_blocks_without_duplicate_contract
    with_repository do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/shaka/bin'))
      File.write(File.join(root, '.agents/shaka/bin/setup'), 'private')
      preview = report(root)
      assert_equal 'blocked', preview.fetch('status')
      assert_includes preview.fetch('blockers').join, 'destination already exists'
      assert_equal 'private', File.read(File.join(root, '.agents/shaka/bin/setup'))
    end
  end

  def test_broken_existing_new_layout_is_not_a_successful_noop
    with_repository do |root|
      report(root, '--apply')
      File.delete(File.join(root, '.agents/shaka/bin/setup'))
      preview = report(root)
      assert_equal 'blocked', preview.fetch('status')
    end
  end

  def test_custom_ruby_root_repair_preserves_execution
    with_repository do |root, parent|
      write_wrapper(root, 'setup', ruby_wrapper("File.expand_path('../..', __dir__)"))
      commit_fixture(root, 'ruby-root')
      before = ruby_result(root, '.agents/bin/setup', parent)
      assert_ruby_repair(root)
      report(root, '--apply')
      assert_equal before, ruby_result(root, '.agents/shaka/bin/setup', parent)
    end
  end

  def ruby_result(root, command, parent)
    output, error, status = Open3.capture3(File.join(root, command), 'arg', chdir: parent)
    [output, error, status.exitstatus]
  end

  def assert_ruby_repair(root)
    kinds = report(root).fetch('repairs').map { |item| item.fetch('kind') }
    assert_includes kinds, 'custom Ruby root discovery'
  end

  def ruby_wrapper(root_expression)
    "#!/usr/bin/env ruby\nroot = #{root_expression}\nDir.chdir(root) { puts ARGV.join(':') }\nexit 17\n"
  end

  def test_shell_root_without_exit_on_error_is_blocked
    with_repository do |root|
      write_wrapper(root, 'setup', "#!/bin/sh\nroot=$(dirname \"$0\")/../..\ncd \"$root\"\n")
      commit_fixture(root, 'no-errexit')
      preview = report(root)
      assert_equal 'blocked', preview.fetch('status')
      assert_includes preview.fetch('blockers').join, 'ambiguous repository-root'
    end
  end
end
