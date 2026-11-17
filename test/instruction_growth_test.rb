# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'
load File.expand_path('../bin/report-instruction-growth', __dir__)

# Builds a throwaway repository holding a committed baseline of Shaka's instruction files.
module InstructionGrowthRepository
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
end

class InstructionGrowthTest < Minitest::Test
  include InstructionGrowthRepository

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
      assert_unknown result
      assert_equal 3, result['entry_workflow_guidance'].first['after']['words']
    end
  end

  def test_rejects_broken_current_workflow
    with_repository do |root|
      write(root, 'skills/shaka/config/workflow.yml', 'version: broken')
      assert_raises(Shaka::Error) { InstructionGrowth.new(root:, base: 'HEAD').report }
    end
  end

  def test_incompatible_baseline_is_unknown_after_current_schema_is_fixed
    with_repository do |root|
      write(root, 'skills/shaka/config/workflow.yml', YAML.dump(workflow_data.merge('legacy_key' => true)))
      commit(root)
      write(root, 'skills/shaka/config/workflow.yml', YAML.dump(workflow_data))
      assert_unknown report(root)
    end
  end

  def test_invalid_utf8_baseline_keeps_current_counts_with_unknown_comparison
    with_repository do |root|
      write(root, 'skills/shaka/references/conditional.md', "\xFF".b)
      commit(root)
      write(root, 'skills/shaka/references/conditional.md', 'Conditional detail.')
      result = report(root)
      assert_unknown result
      assert_match 'UTF-8', result['baseline_error']
    end
  end

  def assert_unknown(result)
    assert_nil result['baseline']
    assert_empty result['other_changed_files']
    result['entry_workflow_guidance'].each do |row|
      assert_equal [nil, nil], row.values_at('before', 'delta')
    end
    assert_operator result['entry_workflow_guidance'][1]['after']['words'], :>, 40
  end
end

class InstructionGrowthMeasurementTest < Minitest::Test
  def test_counts_utf8_bytes_and_rejects_invalid_current_text
    assert_equal({ 'words' => 2, 'bytes' => 8 }, InstructionGrowth.measure('café hi'))
    invalid = "\xFF".b.force_encoding(Encoding::UTF_8)
    assert_raises(Shaka::Error) { InstructionGrowth.measure(invalid) }
  end
end

class InstructionGrowthTokensTest < Minitest::Test
  include InstructionGrowthRepository

  def test_counts_entry_and_rendered_workflow_for_both_revisions
    with_repository do |root|
      grow_workflow(root)
      texts = counted_texts(root)

      assert(texts.values.all? { |text| text.start_with?("Run the workflow.\n\n# Shaka") })
      assert_equal(%i[after], texts.select { |_, text| text.include?('Added instruction.') }.keys)
    end
  end

  def counted_texts(root)
    texts = {}
    counter = ->(**given) { texts.update(given) && [{ 'cli' => 'stub' }] }
    result = InstructionGrowth.new(root:, base: 'HEAD', tokens: counter).report
    assert_equal [{ 'cli' => 'stub' }], result['startup_tokens']['clis']
    assert_includes result['startup_tokens']['note'], 'may be noise'
    texts
  end

  def test_default_report_runs_no_cli_without_the_flag
    with_repository { |root| refute report(root).key?('startup_tokens') }
  end

  # A PATH holding only a link to git hides both CLIs, even where they share git's directory, so the real
  # command reports them missing instead of running them and spending plan quota.
  def test_command_line_flag_adds_unknown_counts_when_the_clis_are_missing
    command = File.expand_path('../bin/report-instruction-growth', __dir__)
    output, status = Dir.mktmpdir do |bindir|
      File.symlink(TEST_GIT, File.join(bindir, File.basename(TEST_GIT)))
      Open3.capture2({ 'PATH' => bindir }, RbConfig.ruby, command, '--tokens', 'HEAD')
    end

    assert_predicate status, :success?
    reasons = JSON.parse(output).dig('startup_tokens', 'clis').map { |row| row['reason'] }
    assert_equal ['claude is not installed', 'codex is not installed'], reasons
  end
end
