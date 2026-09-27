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
      assert_equal 'applied', apply_upgrade(root).fetch('status')
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
      apply_upgrade(linked)
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
      apply_upgrade(root)
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
      error = attempt_failing_upgrade(root)
      assert_includes error.message, 'restored'
      assert_equal 'untouched', File.read(File.join(root, 'notes.txt'))
      assert_legacy_root_restored(root)
      refute_path_exists Shaka::Seam::Upgrader.journal_path(root)
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

  def attempt_failing_upgrade(root)
    digest = report(root).fetch('digest')
    assert_raises(Shaka::Error) { failing_upgrader.new(['--root', root, '--apply', '--digest', digest]).run }
  end

  def test_permission_denial_then_retry
    with_repository do |root|
      directory = File.join(root, '.agents')
      File.chmod(0o555, directory)
      assert_permission_denied(root)
    ensure
      File.chmod(0o755, directory) if directory && File.exist?(directory)
      assert_equal 'applied', apply_upgrade(root).fetch('status') if root
    end
  end

  def assert_permission_denied(root)
    _output, error, status = upgrade(root, '--apply', '--digest', report(root).fetch('digest'))
    refute_predicate status, :success?
    assert_includes error, 'Permission denied'
    assert File.file?(File.join(root, '.agents/agent-workflow.yml'))
    refute_path_exists Shaka::Seam::Upgrader.journal_path(root)
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
      apply_upgrade(root)
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
      apply_upgrade(root)
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
      apply_upgrade(root)
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

class SeamUpgradeReviewFixTest < Minitest::Test
  include SeamUpgradeFixture

  def test_prefix_collisions_are_not_rewritten_but_live_ci_is
    with_repository do |root|
      path = File.join(root, 'ci.yml')
      File.write(path, "run: .agents/bin/test-e2e\nrun: .agents/bin/test\n")
      commit_fixture(root, 'ci')
      apply_upgrade(root)
      assert_equal "run: .agents/bin/test-e2e\nrun: .agents/shaka/bin/test\n", File.read(path)
    end
  end

  def test_live_internal_reference_is_rewritten_and_historical_line_is_kept
    with_repository do |root|
      FileUtils.mkdir_p(File.join(root, 'internal/ci'))
      FileUtils.mkdir_p(File.join(root, 'docs'))
      File.write(File.join(root, 'internal/ci/run.yml'), 'run: .agents/bin/test')
      File.write(File.join(root, 'docs/migration.md'), 'Previously .agents/bin/test')
      commit_fixture(root, 'references')
      apply_upgrade(root)
      assert_reference_contents(root)
    end
  end

  def assert_reference_contents(root)
    assert_equal 'run: .agents/shaka/bin/test', File.read(File.join(root, 'internal/ci/run.yml'))
    assert_equal 'Previously .agents/bin/test', File.read(File.join(root, 'docs/migration.md'))
  end

  def test_reference_to_unmoved_optional_command_blocks
    with_repository do |root|
      File.write(File.join(root, 'README.md'), 'Run .agents/bin/validate-local')
      commit_fixture(root, 'reference')
      preview = report(root)
      assert_equal 'blocked', preview.fetch('status')
      assert_includes preview.fetch('blockers').join, 'unmoved path'
    end
  end

  def test_pathname_root_keeps_its_type
    with_repository do |root, parent|
      write_wrapper(root, 'setup', pathname_wrapper)
      commit_fixture(root, 'pathname')
      before = ruby_execution(root, '.agents/bin/setup', parent)
      apply_upgrade(root)
      assert_equal before, ruby_execution(root, '.agents/shaka/bin/setup', parent)
    end
  end

  def pathname_wrapper
    "#!/usr/bin/env ruby\nrequire 'pathname'\nroot = Pathname(__dir__).parent.parent\n" \
      "Dir.chdir(root) { puts (root / 'bin/probe').exist? }\nexit 7\n"
  end

  def ruby_execution(root, command, parent)
    output, error, status = Open3.capture3(File.join(root, command), chdir: parent)
    [output, error, status.exitstatus]
  end

  def test_pipefail_without_errexit_blocks_shell_repair
    with_repository do |root|
      write_wrapper(root, 'setup', "#!/bin/sh\nset -o pipefail\nroot=$(dirname \"$0\")/../..\n")
      commit_fixture(root, 'pipefail')
      assert_includes report(root).fetch('blockers').join, 'ambiguous repository-root'
    end
  end

  def test_apply_rejects_digest_from_earlier_preview
    with_repository do |root|
      digest = report(root).fetch('digest')
      File.write(File.join(root, 'README.md'), 'Run .agents/bin/test')
      commit_fixture(root, 'new-reference')
      _output, error, status = upgrade(root, '--apply', '--digest', digest)
      refute_predicate status, :success?
      assert_includes error, 'inputs changed'
      assert File.file?(File.join(root, '.agents/agent-workflow.yml'))
    end
  end

  def test_candidate_supplied_journal_does_not_trigger_recovery
    with_repository do |root|
      File.write(File.join(root, '.agents/.shaka-upgrade-journal.json'), 'forged')
      assert_equal 'ready', report(root).fetch('status')
    end
  end

  def test_recovery_refuses_symlink_parent_escape
    with_repository do |root, parent|
      File.symlink(parent, File.join(root, 'evil'))
      write_hostile_journal(root)
      _output, error, status = upgrade(root, '--recover')
      refute_predicate status, :success?
      assert_includes error, 'symlink parent'
      refute_path_exists File.join(parent, 'outside')
    end
  end

  def write_hostile_journal(root)
    entry = 'evil/outside'
    original = { entry => { 'type' => 'file', 'mode' => 0o644, 'data' => ['key'].pack('m0') } }
    desired = { entry => { 'type' => 'absent' } }
    journal = { 'version' => 1, 'original' => original, 'desired' => desired,
                'temporary' => ["#{entry}.shaka-upgrade-tmp"] }
    File.write(Shaka::Seam::Upgrader.journal_path(root), JSON.generate(journal))
  end
end

class SeamUpgradeSecondReviewTest < Minitest::Test
  include SeamUpgradeFixture

  def test_apply_with_existing_journal_fails_without_mutation
    with_repository do |root|
      digest = report(root).fetch('digest')
      write_journal(root, plan_for(root))
      _output, error, status = upgrade(root, '--apply', '--digest', digest)
      refute_predicate status, :success?
      assert_includes error, 'Interrupted upgrade'
      assert File.file?(File.join(root, '.agents/agent-workflow.yml'))
    end
  end

  def test_existing_temporary_file_is_preserved
    with_repository do |root|
      temporary = File.join(root, '.agents/agent-workflow.yml.shaka-upgrade-tmp')
      File.write(temporary, 'user file')
      _output, error, status = upgrade(root, '--apply', '--digest', report(root).fetch('digest'))
      refute_predicate status, :success?
      assert_includes error, 'Existing upgrade temporary file'
      assert_equal 'user file', File.read(temporary)
      refute_path_exists Shaka::Seam::Upgrader.journal_path(root)
    end
  end

  def test_vendored_path_is_not_rewritten
    with_repository do |root|
      path = File.join(root, 'ci.yml')
      File.write(path, 'run: vendor/tool/.agents/bin/test')
      commit_fixture(root, 'vendor')
      apply_upgrade(root)
      assert_equal 'run: vendor/tool/.agents/bin/test', File.read(path)
    end
  end

  def test_mode_flags_are_checked
    with_repository do |root|
      digest = report(root).fetch('digest')
      [['--digest', digest], ['--apply'], ['--apply', '--recover', '--digest', digest]].each do |flags|
        _output, _error, status = upgrade(root, *flags)
        refute_predicate status, :success?
      end
    end
  end

  def test_apply_on_already_upgraded_layout_is_a_noop
    with_repository do |root|
      apply_upgrade(root)
      assert_equal 'already_upgraded', apply_upgrade(root).fetch('status')
    end
  end

  def test_symlink_to_another_moved_command_keeps_target
    with_repository do |root|
      path = File.join(root, '.agents/bin/validate')
      File.delete(path)
      File.symlink('test', path)
      commit_fixture(root, 'linked-command')
      apply_upgrade(root)
      assert_equal 'test', File.readlink(File.join(root, '.agents/shaka/bin/validate'))
    end
  end

  def test_tracked_executable_reference_blocks
    with_repository do |root|
      path = File.join(root, 'run-ci')
      File.write(path, "#!/bin/sh\nexec .agents/bin/test \"$@\"\n")
      File.chmod(0o755, path)
      commit_fixture(root, 'executable-reference')
      assert_includes report(root).fetch('blockers').join, 'executable old-path reference'
    end
  end

  def test_symlinked_legacy_command_directory_blocks
    with_repository do |root|
      FileUtils.mv(File.join(root, '.agents/bin'), File.join(root, 'old-bin'))
      File.symlink('../old-bin', File.join(root, '.agents/bin'))
      assert_includes report(root).fetch('blockers').join, 'expected a real directory'
    end
  end
end

class SeamUpgradeReferenceSafetyTest < Minitest::Test
  include SeamUpgradeFixture

  def test_dynamic_and_absolute_references_block_without_touching_files
    with_repository do |root|
      path = File.join(root, '.github/workflows/ci.yml')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, dynamic_references)
      commit_fixture(root, 'dynamic paths')
      assert_blocked_with(root, 'dynamic old-path reference')
      assert_includes File.read(path), '${root}/.agents/bin/test'
    end
  end

  def dynamic_references
    <<~TEXT
      run: ${root}/.agents/bin/test
      run: ${{ github.workspace }}/.agents/bin/test
      run: /repo/.agents/bin/test
    TEXT
  end

  def test_moved_script_with_sibling_dependency_blocks
    with_repository do |root|
      write_wrapper(root, 'setup', "#!/bin/sh\nset -eu\n. \"$(dirname \"$0\")/common.sh\"\n")
      commit_fixture(root, 'sibling dependency')
      assert_blocked_with(root, 'invocation-relative dependency')
    end
  end

  def test_inbound_symlink_to_moved_command_blocks
    with_repository do |root|
      File.symlink('../.agents/bin/test', File.join(root, 'bin/test'))
      commit_fixture(root, 'inbound link')
      assert_blocked_with(root, 'symlink targets moved')
    end
  end

  def test_release_history_keeps_old_paths
    with_repository do |root|
      path = File.join(root, 'CHANGELOG.md')
      File.write(path, '- Added `.agents/bin/test` wrapper (v1.2)')
      commit_fixture(root, 'history')
      apply_upgrade(root)
      assert_equal '- Added `.agents/bin/test` wrapper (v1.2)', File.read(path)
    end
  end

  def test_existing_journal_temporary_file_is_preserved
    with_repository do |root|
      temporary = "#{Shaka::Seam::Upgrader.journal_path(root)}.tmp"
      File.write(temporary, 'leave me')
      _output, error, status = upgrade(root, '--apply', '--digest', report(root).fetch('digest'))
      refute_predicate status, :success?
      assert_includes error, 'Existing upgrade journal temporary file'
      assert_equal 'leave me', File.read(temporary)
    end
  end

  def test_failure_during_destination_creation_restores_sources
    with_repository do |root|
      digest = report(root).fetch('digest')
      assert_raises(Shaka::Error) { failing_creator.new(['--root', root, '--apply', '--digest', digest]).run }
      assert File.file?(File.join(root, '.agents/agent-workflow.yml'))
      refute_path_exists File.join(root, '.agents/shaka/config.yml')
      refute_path_exists Shaka::Seam::Upgrader.journal_path(root)
    end
  end

  def failing_creator
    Class.new(Shaka::Seam::Upgrader) do
      private

      def write_new_state(relative, state)
        @created = (@created || 0) + 1
        raise Errno::EIO, 'injected creation failure' if @created == 2

        super
      end
    end
  end

  def test_set_o_errexit_allows_custom_shell_root_repair
    with_repository do |root|
      write_wrapper(root, 'setup', "#!/bin/sh\nset -o errexit\nroot=$(dirname \"$0\")/../..\nexit 0\n")
      commit_fixture(root, 'errexit')
      assert_equal 'ready', report(root).fetch('status')
    end
  end
end

class SeamUpgradeDependencySafetyTest < Minitest::Test
  include SeamUpgradeFixture

  def test_other_ruby_and_shell_relative_paths_block
    ["root = File.join(__dir__, '..', '..')\n", "require_relative 'common'\n",
     ". \"${BASH_SOURCE%/*}/common.sh\"\n"].each do |body|
      with_repository do |root|
        write_wrapper(root, 'setup', "#!/bin/sh\n#{body}")
        commit_fixture(root, 'relative dependency')
        assert_blocked_with(root, 'invocation-relative dependency')
      end
    end
  end

  def test_directory_globs_and_codeowners_block
    with_repository do |root|
      FileUtils.mkdir_p(File.join(root, '.github/workflows'))
      File.write(File.join(root, '.github/CODEOWNERS'), '/.agents/bin/ @maintainers')
      File.write(File.join(root, '.github/workflows/ci.yml'), "paths: ['.agents/bin/**']")
      commit_fixture(root, 'directory references')
      preview = report(root)
      assert_equal 'blocked', preview.fetch('status')
      count = preview.fetch('blockers').count { |item| item.include?('old command-directory') }
      assert_equal 2, count
    end
  end

  def test_live_readme_instruction_with_formerly_is_rewritten
    with_repository do |root|
      path = File.join(root, 'README.md')
      File.write(path, 'Run .agents/bin/test (formerly make test).')
      commit_fixture(root, 'live instruction')
      apply_upgrade(root)
      assert_equal 'Run .agents/shaka/bin/test (formerly make test).', File.read(path)
    end
  end
end
