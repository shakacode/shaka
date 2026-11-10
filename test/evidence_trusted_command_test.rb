# frozen_string_literal: true

require_relative 'trusted_command_fixture'

# Evidence for a branch that predates the command directory comes from the trusted copy.
class EvidenceTrustedCommandTest < Minitest::Test
  include TrustedCommandFixture

  def test_run_uses_the_trusted_command_when_the_candidate_predates_the_settings
    with_older_branch do |root, trusted, head|
      result = run_check(root, trusted, command: 'validate')

      assert_equal 'completed', result.fetch('status')
      assert_equal 'trusted_ref', result.fetch('command_source')
      refute_path_exists File.join(root, '.agents'), 'the trusted copy is removed after the run'
      assert_equal 'bound', bind(root, trusted, head, result).fetch('status')
      assert_equal 'bound', verified_validation(root, trusted, head, result).fetch('status')
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

  def test_candidate_command_directory_missing_one_command_still_fails
    with_checkout do |root, trusted|
      File.delete(File.join(root, '.agents/shaka/bin/validate'))

      assert_includes refused_run(root, trusted), '.agents/shaka/bin/validate does not exist'
      refute_path_exists File.join(root, '.agents/shaka/bin/validate')
    end
  end

  def test_changed_trusted_command_supersedes_the_result
    with_older_branch do |root, trusted, head|
      result = run_check(root, trusted, command: 'validate')
      newer = change_trusted_validate(root, trusted, head)
      binding = bind(root, newer, head, result)

      assert_equal 'superseded', binding.fetch('status')
      assert_includes binding.fetch('changed_settings_components'), 'files'
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

  # A later default-branch commit whose validate script differs, leaving the candidate unchanged.
  def change_trusted_validate(root, trusted, head)
    git(root, 'checkout', '--quiet', trusted)
    File.write(File.join(root, '.agents/shaka/bin/validate'), "#{VALIDATE}echo changed\n")
    newer = commit_all(root)
    git(root, 'checkout', '--quiet', head)
    newer
  end

  def verified_validation(root, trusted, head, result)
    Tempfile.create(['shaka-validation-', '.json']) do |file|
      file.write(JSON.generate(result))
      file.flush
      verify(root, head, ref: trusted, validation: file.path).dig('checks', 'validation', 0)
    end
  end
end
