# frozen_string_literal: true

require_relative 'test_helper'
require 'tempfile'
require 'rbconfig'
require 'shaka/local_review/cli'

class ReviewerFailureCauseTest < Minitest::Test
  REFUSAL = "The 'gpt-6-sol' model is not supported when using Codex with a ChatGPT account."

  def test_native_error_event_identifies_account_refusal
    with_failure('', JSON.generate(type: 'error', message: REFUSAL)) do |result|
      assert_equal 'account_model_refused', result.fetch('failure_cause')
      assert_equal 'not_eligible', result.fetch('skip_evidence')
      assert_path_exists result.fetch('diagnostic_path')
    end
  end

  def test_failed_turn_error_identifies_account_refusal
    with_failure('', JSON.generate(type: 'turn.failed', error: { message: REFUSAL })) do |result|
      assert_equal 'account_model_refused', result.fetch('failure_cause')
    end
  end

  def test_candidate_tool_output_and_plain_prose_do_not_change_a_quota_failure
    event = JSON.generate(type: 'item.completed', item: { type: 'command_execution', aggregated_output: REFUSAL })
    with_failure('ERROR: quota exhausted', "#{event}\n#{REFUSAL}\n") do |result|
      refute result.key?('failure_cause')
      assert_equal 'requires_cause_review', result.fetch('skip_evidence')
    end
  end

  def test_generic_model_not_found_is_not_account_availability_evidence
    message = 'The model gpt-9-nova does not exist or you do not have access to it.'
    event = JSON.generate(type: 'error', message:, code: 'model_not_found')
    with_failure('', event) do |result|
      refute result.key?('failure_cause')
      assert_equal 'requires_cause_review', result.fetch('skip_evidence')
    end
  end

  def test_stderr_error_prose_is_only_diagnostic
    with_failure("ERROR: #{REFUSAL}\n", '') do |result|
      refute result.key?('failure_cause')
      assert_equal 'requires_cause_review', result.fetch('skip_evidence')
    end
  end

  def test_wrapped_http_error_detail_identifies_account_refusal
    message = "unexpected status 400 Bad Request: #{JSON.generate(detail: REFUSAL)}"
    with_failure('', JSON.generate(type: 'error', message:)) do |result|
      assert_equal 'account_model_refused', result.fetch('failure_cause')
    end
  end

  private

  def with_failure(stderr, stdout)
    status = Open3.capture3(RbConfig.ruby, '-e', 'exit 1').last
    Tempfile.create('failure-cause-report') do |report|
      options = { reviewer: 'openai/codex', timeout_seconds: 1 }
      cli = Shaka::LocalReviewCli.new(options, root: Dir.tmpdir, report: report.path, candidate_root: Dir.pwd)
      result = cli.send(:process_failure, 'codex exec', status, stderr, stdout)
      yield result
    ensure
      File.unlink(result['diagnostic_path']) if result && File.exist?(result['diagnostic_path'].to_s)
    end
  end
end
