# frozen_string_literal: true

require_relative 'evidence_mapping_fixture'

# Exercise a selector that requires explicit mappings, followed by a required check.
class EvidenceMappingValidationTest < Minitest::Test
  include EvidenceMappingFixture

  def test_unmapped_validation_fails
    with_mapping_checkout do |root, ref|
      failed = run_check(root, ref, command: 'validate', expected_exit: 1)
      assert_equal 64, failed.fetch('exit_code')
      with_results(validation: failed, review: review_check(root, ref)) do |paths|
        assert_equal 'not_ready', verify(root, ref, **paths).fetch('status')
      end
    end
  end

  def test_successful_ad_hoc_mappings_explain_the_supported_repair
    with_mapping_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate', arguments: ['--', *MAPPINGS])
      with_results(validation:, review: review_check(root, ref)) do |paths|
        verdict = verify(root, ref, **paths)
        assert_equal 'not_ready', verdict.fetch('status')
        entry = verdict.fetch('checks').fetch('validation').first
        assert_includes entry.fetch('guidance'), 'repository-setup.md#required-validation-inputs'
      end
    end
  end

  def test_fixed_mappings_satisfy_validation_without_argument_overrides
    with_mapping_checkout(fixed: true) do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      assert_empty validation.dig('task_overrides', 'arguments')
      with_results(validation:, review: review_check(root, ref)) do |paths|
        assert_equal 'ready', verify(root, ref, **paths).fetch('status')
      end
    end
  end

  def test_existing_repository_script_can_supply_mappings_without_wrapper_changes
    with_mapping_checkout do |root, base|
      supply_default_mappings(root)
      head = commit_changes(root)
      assert_equal 'clear', Shaka::Configuration::FeatureGuard.check(root:, base:, head:).fetch('status')
      validation = run_check(root, base, command: 'validate')
      with_results(validation:, review: review_check(root, head)) do |paths|
        assert_equal 'ready', verify(root, head, **paths).fetch('status')
      end
    end
  end

  def test_required_check_failure_cannot_be_hidden_by_passing_mappings
    with_mapping_checkout(fixed: true) do |root, _ref|
      File.write(File.join(root, 'script/security.rb'), "exit 9\n")
      ref = commit_changes(root)
      validation = run_check(root, ref, command: 'validate', expected_exit: 1)
      assert_equal 9, validation.fetch('exit_code')
      with_results(validation:, review: review_check(root, ref)) do |paths|
        assert_equal 'not_ready', verify(root, ref, **paths).fetch('status')
      end
    end
  end

  def test_unmapped_changed_file_still_blocks_fixed_mappings
    with_mapping_checkout(fixed: true) do |root, _ref|
      File.write(File.join(root, 'changed-files.json'), JSON.generate(['app/unmapped.rb']))
      ref = commit_changes(root)
      validation = run_check(root, ref, command: 'validate', expected_exit: 1)
      with_results(validation:, review: review_check(root, ref)) do |paths|
        assert_equal 'not_ready', verify(root, ref, **paths).fetch('status')
      end
    end
  end

  def test_changed_mapping_cannot_reuse_old_evidence
    with_mapping_checkout(fixed: true) do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      path = File.join(root, '.agents/bin/validate')
      File.write(path, File.read(path).sub('spec/new_spec.rb', 'spec/other_spec.rb'))
      git(root, 'add', '-A')
      commit(root)
      head = git(root, 'rev-parse', 'HEAD')
      assert_includes bind(root, ref, head, validation).fetch('reasons'), 'candidate tree differs from tested tree'
    end
  end

  def test_relabeling_argument_evidence_as_no_argument_evidence_is_rejected
    with_mapping_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate', arguments: ['--', *MAPPINGS])
      validation.fetch('task_overrides')['arguments'] = []
      with_results(validation:, review: review_check(root, ref)) do |paths|
        verdict = verify(root, ref, **paths)
        reasons = verdict.fetch('checks').fetch('validation').first.fetch('reasons')
        assert_includes reasons, 'settings components differ: effective_settings'
      end
    end
  end

  def test_shell_syntax_is_literal_input_and_cannot_satisfy_validation
    with_mapping_checkout do |root, ref|
      marker = File.join(root, 'executed')
      validation = run_check(root, ref, command: 'validate',
                                        arguments: ['--', *MAPPINGS, "$(touch #{marker})"], expected_exit: 1)
      refute_path_exists marker
      with_results(validation:, review: review_check(root, ref)) do |paths|
        assert_equal 'not_ready', verify(root, ref, **paths).fetch('status')
      end
    end
  end
end
