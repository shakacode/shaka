# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/release_behavior_fixture'

class EvaluationReleaseBehaviorCliTest < Minitest::Test
  include ReleaseBehaviorFixture

  COMMAND = File.join(ROOT, 'eval/bin/release-behavior')

  def test_help_explains_the_offline_inputs
    output, error, status = Open3.capture3(RbConfig.ruby, COMMAND, '--help')
    assert_predicate status, :success?, error
    assert_includes output, '--skill'
    assert_includes output, '--records'
    assert_includes output, '--commit'
  end

  def test_invalid_input_is_refused_without_echoing_private_contents
    Dir.mktmpdir do |directory|
      file = File.join(directory, 'private-records.json')
      File.write(file, 'private malformed input')
      output, _, status = Open3.capture3(RbConfig.ruby, COMMAND, '--skill', ROOT,
                                         '--commit', @commit, '--records', file)
      refute_predicate status, :success?
      assert_equal 'unreadable_or_invalid_input', JSON.parse(output)['reason']
      refute_includes output, 'private'
    end
  end

  def test_real_cli_passes_a_complete_batch
    assert_cli_result(true)
  end

  def test_real_cli_refuses_a_failed_decision
    first['gate'].first['passed'] = false
    assert_cli_result(false)
  end

  def test_real_cli_refuses_records_for_another_release_commit
    @commit = 'a' * 40
    assert_cli_result(false)
  end

  def test_publication_cases_use_the_existing_exact_action_grader
    cases = E::ReleaseSafetyBank.cases.to_h { [it.fetch('id'), it] }
    response = { 'actions' => ['publish_release'], 'reason' => 'Synthetic decision' }
    assert E::MergeAuthorization.check(cases.fetch('release-with-approval'), response)['passed']
    refute E::MergeAuthorization.check(cases.fetch('release-without-approval'), response)['passed']
    prompt = E::ReleaseSafetyBank.prompt('release-without-approval', 'Synthetic workflow')
    assert_includes prompt, 'Synthetic workflow'
    refute_includes prompt, '"expected"'
    assert_raises(ArgumentError) { E::ReleaseSafetyBank.prompt('missing', '') }
  end

  private

  def assert_cli_result(passed)
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'synthetic-records.json')
      File.write(path, JSON.generate(@records))
      output, error, status = run_cli(path)
      assert_equal passed, status.success?, error
      assert_equal passed ? 'passed' : 'refused', JSON.parse(output)['status']
      refute JSON.parse(output)['publication_authorized']
      refute_includes output, '/synthetic/transcript.jsonl'
    end
  end
end
