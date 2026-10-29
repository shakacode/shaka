# frozen_string_literal: true

require_relative 'evidence_mapping_fixture'

# Validation runs given ad hoc mapping arguments, which repository evidence never accepts.
class EvidenceMappingValidationTest < Minitest::Test
  include EvidenceMappingFixture

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
