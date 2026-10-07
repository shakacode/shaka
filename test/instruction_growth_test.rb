# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'
load File.expand_path('../bin/report-instruction-growth', __dir__)

class InstructionGrowthTest < Minitest::Test
  def with_repository
    Dir.mktmpdir do |root|
      system(TEST_GIT, '-C', root, 'init', '-q') or raise 'git init failed'
      seed(root)
      yield root
    end
  end

  def write(root, path, text)
    destination = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, text)
  end

  def seed(root)
    write(root, 'skills/shaka/SKILL.md', 'Run the workflow.')
    write(root, 'skills/shaka/config/workflow.yml', YAML.dump(workflow_data))
    write(root, 'skills/shaka/references/conditional.md', 'Conditional detail.')
    commit(root)
  end

  def commit(root)
    system(TEST_GIT, '-C', root, 'add', '.') or raise 'git add failed'
    system(TEST_GIT, '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '-qm', 'baseline') or raise 'git commit failed'
  end

  def workflow_data
    { 'version' => 1, 'title' => 'Shaka', 'purpose' => 'Deliver tasks.',
      'always' => 'Keep boundaries.', 'code_quality' => 'Use Ruby.',
      'phases' => Shaka::WorkflowConfig::PHASE_IDS.map do |id|
        { 'id' => id, 'title' => id, 'body' => 'Do work.', 'done_when' => 'Complete.' }
      end }
  end

  def report(root, base = 'HEAD') = InstructionGrowth.new(root:, base:).report

  def grow_workflow(root)
    data = workflow_data
    data['phases'].first['body'] += ' Added instruction.'
    write(root, 'skills/shaka/config/workflow.yml', YAML.dump(data))
  end

  def test_reports_rendered_growth_even_when_entrypoint_is_unchanged
    with_repository do |root|
      grow_workflow(root)
      result = report(root)
      assert_equal([0, 2, 0], result['entry_workflow_guidance'].map { |row| row['delta']['words'] })
      assert_operator result['entry_workflow_guidance'][1]['after']['words'], :>, 40
      assert_empty result['other_changed_files']
    end
  end

  def test_conditional_additions_and_deletions_do_not_change_core_counts
    with_repository do |root|
      File.delete(File.join(root, 'skills/shaka/references/conditional.md'))
      write(root, '.agents/shaka/review-prompt.md', 'Check actual costs.')

      result = report(root)
      assert_equal([0, 0, 0], result['entry_workflow_guidance'].map { |row| row['delta']['words'] })
      changes = conditional_words(result)
      assert_equal(-2, changes['skills/shaka/references/conditional.md'])
      assert_equal 3, changes['.agents/shaka/review-prompt.md']
    end
  end

  def conditional_words(result)
    result['other_changed_files'].to_h { |row| [row['surface'], row['delta']['words']] }
  end

  def test_missing_baseline_is_unknown_rather_than_zero_growth
    with_repository do |root|
      result = report(root, 'missing')
      assert_nil result['baseline']
      result['entry_workflow_guidance'].each do |row|
        assert_nil row['before']
        assert_nil row['delta']
      end
      assert_equal 3, result['entry_workflow_guidance'].first['after']['words']
    end
  end

  def test_counts_utf8_bytes_and_rejects_broken_workflow
    assert_equal({ 'words' => 2, 'bytes' => 8 }, InstructionGrowth.measure('café hi'))
    with_repository do |root|
      write(root, 'skills/shaka/config/workflow.yml', 'version: broken')
      assert_raises(Shaka::Error) { InstructionGrowth.new(root:, base: 'HEAD').report }
    end
  end

  def test_incompatible_baseline_is_unknown_after_current_schema_is_fixed
    with_repository do |root|
      incompatible_baseline(root)
      result = report(root)
      assert_nil result['baseline']
      assert_nil result['entry_workflow_guidance'][1]['delta']
      assert_operator result['entry_workflow_guidance'][1]['after']['words'], :>, 40
    end
  end

  def incompatible_baseline(root)
    write(root, 'skills/shaka/config/workflow.yml', YAML.dump(workflow_data.merge('legacy_key' => true)))
    commit(root)
    write(root, 'skills/shaka/config/workflow.yml', YAML.dump(workflow_data))
  end
end
