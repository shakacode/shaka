# frozen_string_literal: true

require_relative 'evidence_mapping_fixture'

class EvidenceMappingSelectorTest < Minitest::Test
  include EvidenceMappingFixture

  def test_existing_repository_script_can_supply_mappings_without_wrapper_changes
    with_mapping_checkout do |root, base|
      supply_durable_selector_rules(root)
      head = commit_changes(root)
      assert_equal 'clear', Shaka::Configuration::FeatureGuard.check(root:, base:, head:).fetch('status')
      validation = run_check(root, base, command: 'validate')
      with_results(validation:, review: review_check(root, head)) do |paths|
        assert_equal 'ready', verify(root, head, ref: base, **paths).fetch('status')
      end
    end
  end

  def test_durable_selector_rules_keep_unknown_changed_files_blocked
    with_mapping_checkout do |root, base|
      supply_durable_selector_rules(root)
      File.write(File.join(root, 'changed-files.json'), JSON.generate(['app/unmapped.rb']))
      head = commit_changes(root)
      validation = run_check(root, base, command: 'validate', expected_exit: 1)
      assert_equal 64, validation.fetch('exit_code')
      with_results(validation:, review: review_check(root, head)) do |paths|
        assert_equal 'not_ready', verify(root, head, ref: base, **paths).fetch('status')
      end
    end
  end
end
