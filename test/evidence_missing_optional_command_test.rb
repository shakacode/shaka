# frozen_string_literal: true

require_relative 'evidence_fixture'

# A branch that has the command directory but predates an optional script the default branch added
# runs its other commands; the missing script is skipped, never run from the trusted commit.
class EvidenceMissingOptionalCommandTest < Minitest::Test
  include EvidenceFixture

  VALIDATE_LOCAL = '.agents/shaka/bin/validate-local'
  TRIGGER = '.agents/shaka/bin/trigger-hosted-ci'

  def test_validate_runs_and_counts_when_the_candidate_lacks_validate_local
    with_older_branch do |root, trusted, head|
      result = run_check(root, trusted, command: 'validate')

      assert_equal 'completed', result.fetch('status')
      refute result.key?('command_source')
      fingerprinted = result.dig('settings', 'components', 'files').keys
      assert_includes fingerprinted, '.agents/shaka/bin/validate'
      refute_includes fingerprinted, VALIDATE_LOCAL
      assert_equal 'bound', bind(root, trusted, head, result).fetch('status')
      assert_equal 'bound', verified_validation(root, trusted, head, result).fetch('status')
    end
  end

  def test_validate_local_is_refused_when_the_candidate_lacks_it
    with_older_branch do |root, trusted, _head|
      _output, error = capture_io do
        assert_equal 1, Shaka::Evidence::Command.run(
          ['run', '--root', root, '--ref', trusted, '--repository', 'shakacode/shaka', '--command', 'validate_local']
        )
      end

      assert_includes error, 'validate_local is not configured for this repository'
      refute_path_exists File.join(root, VALIDATE_LOCAL)
    end
  end

  def test_settings_omit_the_missing_script
    with_older_branch do |root, trusted, _head|
      commands = Shaka::Configuration.trusted(root:, ref: trusted).commands

      refute commands.key?('validate_local')
      assert_equal '.agents/shaka/bin/validate', commands.fetch('validate')
    end
  end

  def test_trigger_without_validate_local_is_still_refused
    with_older_branch(extra: ['trigger_hosted_ci']) do |root, trusted, _head|
      File.write(File.join(root, TRIGGER), "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, File.join(root, TRIGGER))

      error = assert_raises(Shaka::Error) { Shaka::Configuration.trusted(root:, ref: trusted) }
      assert_includes error.message, "#{TRIGGER} requires #{VALIDATE_LOCAL}"
    end
  end

  def test_a_missing_required_script_is_still_refused
    with_older_branch do |root, trusted, _head|
      File.delete(File.join(root, '.agents/shaka/bin/test'))

      error = assert_raises(Shaka::Error) { Shaka::Configuration.trusted(root:, ref: trusted) }
      assert_includes error.message, '.agents/shaka/bin/test does not exist'
    end
  end

  private

  # The trusted commit adds optional scripts; the candidate commit after it removes them, like an
  # older branch that already had the command directory.
  def with_older_branch(extra: [])
    with_checkout do |root, _initial|
      names = ['validate_local', *extra]
      names.each { create_command(root, it) }
      trusted = commit_all(root)
      git(root, 'rm', '--quiet', *names.map { optional_commands.fetch(it) })
      File.write(File.join(root, 'candidate.txt'), "older branch\n")
      yield root, trusted, commit_all(root)
    end
  end

  def commit_all(root)
    git(root, 'add', '-A')
    commit(root)
    git(root, 'rev-parse', 'HEAD')
  end

  def verified_validation(root, trusted, head, result)
    Tempfile.create(['shaka-validation-', '.json']) do |file|
      file.write(JSON.generate(result))
      file.flush
      verify(root, head, ref: trusted, validation: file.path).dig('checks', 'validation', 0)
    end
  end
end
