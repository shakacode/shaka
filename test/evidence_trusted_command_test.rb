# frozen_string_literal: true

require_relative 'evidence_fixture'

# A branch cut before the repository added its Shaka settings has no command directory.
class EvidenceTrustedCommandTest < Minitest::Test
  include EvidenceFixture

  # Finds the checkout the way generated commands do, then proves it sees the candidate's own file.
  VALIDATE = <<~SH
    #!/bin/sh
    set -eu
    root=$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)
    test -f "$root/candidate.txt"
    echo "validated $root"
  SH

  def test_run_uses_the_trusted_command_when_the_candidate_predates_the_settings
    with_older_branch do |root, trusted, head|
      result = run_check(root, trusted, command: 'validate')

      assert_equal 'completed', result.fetch('status')
      assert_equal 'trusted_ref', result.fetch('command_source')
      refute_path_exists File.join(root, '.agents'), 'the trusted copy is removed after the run'
      assert_equal 'bound', bind(root, trusted, head, result).fetch('status')
    end
  end

  def test_run_reports_failure_of_the_trusted_command
    with_older_branch do |root, trusted, _head|
      File.delete(File.join(root, 'candidate.txt'))
      result = run_check(root, trusted, command: 'validate', expected_exit: 1)

      assert_equal 'not_completed', result.fetch('status')
      refute_path_exists File.join(root, '.agents')
    end
  end

  def test_run_keeps_unrelated_agents_files
    with_older_branch do |root, trusted, _head|
      FileUtils.mkdir_p(File.join(root, '.agents/skills'))
      File.write(File.join(root, '.agents/skills/note.md'), "kept\n")
      run_check(root, trusted, command: 'validate')

      assert_equal %w[skills], Dir.children(File.join(root, '.agents'))
    end
  end

  def test_candidate_command_directory_missing_one_command_still_fails
    with_checkout do |root, trusted|
      File.delete(File.join(root, '.agents/shaka/bin/setup'))

      assert_includes refused_run(root, trusted), '.agents/shaka/bin/setup does not exist'
    end
  end

  def test_failed_write_removes_the_partial_copy
    with_older_branch do |root, trusted, _head|
      copy = trusted_copy(root, trusted)
      unwritable = Object.new
      def unwritable.to_s = raise(Errno::ENOSPC)
      copy.instance_variable_set(:@text, unwritable)

      assert_raises(Errno::ENOSPC) { copy.with { flunk 'command ran' } }

      refute_path_exists File.join(root, '.agents')
    end
  end

  def test_trusted_copy_refuses_a_symlinked_parent
    with_older_branch do |root, trusted, _head|
      Dir.mktmpdir do |outside|
        copy = trusted_copy(root, trusted)
        File.symlink(outside, File.join(root, '.agents'))

        assert_raises(Shaka::Error) { copy.with { flunk 'command ran' } }
        assert_empty Dir.children(outside)
      end
    end
  end

  def test_settings_report_no_candidate_command_directory
    with_older_branch do |root, trusted, _head|
      paths = Shaka::Configuration.trusted(root:, ref: trusted).to_h.fetch('paths')

      assert_nil paths.fetch('candidate_command_directory')
      assert_equal '.agents/shaka/bin', paths.fetch('trusted_command_directory')
    end
  end

  def test_symlinked_agents_directory_is_refused
    with_older_branch do |root, trusted, _head|
      Dir.mktmpdir do |outside|
        File.symlink(outside, File.join(root, '.agents'))

        assert_includes refused_run(root, trusted), 'must be a real directory'
        assert_empty Dir.children(outside)
      end
    end
  end

  private

  def trusted_copy(root, trusted)
    Shaka::Evidence::TrustedCommand.new(root, trusted, '.agents/shaka/bin/validate')
  end

  def refused_run(root, trusted)
    _output, error = capture_io do
      assert_equal 1, Shaka::Evidence::Command.run(
        ['run', '--root', root, '--ref', trusted, '--repository', 'shakacode/shaka', '--command', 'validate']
      )
    end
    error
  end

  # The trusted commit has the settings; the candidate commit after it removes them, like an older branch.
  def with_older_branch
    with_checkout do |root, _initial|
      File.write(File.join(root, '.agents/shaka/bin/validate'), VALIDATE)
      trusted = commit_all(root)
      git(root, 'rm', '-r', '--quiet', '.agents')
      File.write(File.join(root, 'candidate.txt'), "older branch\n")
      yield root, trusted, commit_all(root)
    end
  end

  def commit_all(root)
    git(root, 'add', '-A')
    commit(root)
    git(root, 'rev-parse', 'HEAD')
  end
end
