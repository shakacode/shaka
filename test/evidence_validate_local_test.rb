# frozen_string_literal: true

require_relative 'evidence_fixture'

# A validate-local run counts as repository validation only without arguments and only when the trusted ref has it.
class EvidenceValidateLocalTest < Minitest::Test
  include EvidenceFixture

  def test_validate_local_without_arguments_satisfies_repository_validation
    with_checkout do |root, _ref|
      ref = add_validate_local(root)
      validation = run_check(root, ref, command: 'validate_local')
      with_results(validation:, review: review_check(root, ref)) do |paths|
        assert_equal 'ready', verify(root, ref, **paths).fetch('status')
      end
    end
  end

  def test_validate_local_run_is_refused_until_the_trusted_ref_has_it
    with_checkout do |root, base|
      add_validate_local(root)
      _output, error = capture_io do
        assert_equal 1, Shaka::Evidence::Command.run(
          ['run', '--root', root, '--ref', base, '--repository', 'shakacode/shaka', '--command', 'validate_local']
        )
      end
      assert_includes error, 'validate_local is not configured for this repository'
    end
  end

  def test_validate_local_result_is_refused_when_the_trusted_ref_lacks_the_script
    with_checkout do |root, base|
      head = add_validate_local(root)
      validation = run_check(root, head, command: 'validate_local')
      with_results(validation:, review: review_check(root, head)) do |paths|
        verdict = verify(root, head, ref: base, **paths)
        assert_equal 'not_ready', verdict.fetch('status')
        assert_includes validation_entry(verdict).fetch('reasons'), 'expected repository validation command'
      end
    end
  end

  def test_validate_local_with_arguments_cannot_satisfy_repository_validation
    with_checkout do |root, _ref|
      ref = add_validate_local(root)
      validation = run_check(root, ref, command: 'validate_local', arguments: ['--', '--changed'])
      with_results(validation:, review: review_check(root, ref)) do |paths|
        entry = validation_entry(verify(root, ref, **paths))
        assert_equal 'superseded', entry.fetch('status')
        assert_includes entry.fetch('reasons'), 'repository validation used command arguments'
      end
    end
  end

  private

  def add_validate_local(root)
    path = File.join(root, '.agents/shaka/bin/validate-local')
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, path)
    git(root, 'add', '-A')
    commit(root)
    git(root, 'rev-parse', 'HEAD')
  end

  def validation_entry(verdict) = verdict.fetch('checks').fetch('validation').first
end
