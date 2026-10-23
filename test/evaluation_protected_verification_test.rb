# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_capture'
require_relative '../eval/lib/shaka/evaluation/protected_verification'
require_relative 'support/evaluation_capture_fixture'

class EvaluationProtectedVerificationTest < Minitest::Test
  include EvaluationCaptureFixture

  def test_observer_runs_protected_verification_before_releasing_the_agent
    receipt = nil
    body = "File.write('verified', ENV.fetch('VERIFIER_MARKER')); File.write('release', 'go'); puts 'private evidence'"
    result = run_child(wait_for_verification) do |event|
      receipt = verify(body) if event.dig('native', 'type') == 'turn.started'
    end
    assert_equal 'completed', result.fetch('native_status')
    assert_protected_marker
    assert_operator receipt.fetch('finished_at'), :<=, result.dig('terminal', 'received_at')
    assert_private_receipt(receipt)
    refute result.fetch('command_capture_complete')
  end

  def test_nonzero_exit_is_retained_without_becoming_a_pass
    receipt = verify("warn 'hidden failure'; exit 7")
    assert_equal 7, receipt.fetch('exit_code')
    assert_equal "hidden failure\n", File.read(verifier_log)
  end

  def test_verifier_timeout_aborts_capture_and_reaps_both_processes
    body = "File.write('verifier-pid', Process.pid); sleep 30"
    assert_raises(IOError) do
      run_child("File.write('pid', Process.pid); #{wait_for_verification}") do |event|
        verify(body, seconds: 0.2) if event.dig('native', 'type') == 'turn.started'
      end
    end
    %w[pid verifier-pid].each { refute_process(Integer(File.read(File.join(@root, it)))) }
  end

  def test_output_overflow_aborts_and_keeps_a_bounded_private_log
    assert_raises(IOError) { verify("STDOUT.write('x' * 2_000_000); sleep 30") }
    assert_operator File.size(verifier_log), :<=, 1_048_576
  end

  def test_explicit_environment_does_not_inherit_agent_or_host_values
    ENV['VERIFIER_HOST_SECRET'] = 'not for the verifier'
    receipt = verify("exit(ENV['VERIFIER_HOST_SECRET'].nil? && ENV['VERIFIER_MARKER'] == 'protected' ? 0 : 1)")
    assert_equal 0, receipt.fetch('exit_code')
  ensure
    ENV.delete('VERIFIER_HOST_SECRET')
  end

  def test_completed_parent_cannot_leave_a_descendant_running
    receipt = verify("fork { File.write('descendant', Process.pid); sleep 30 }; sleep 0.1")
    assert_equal 0, receipt.fetch('exit_code')
    pid = Integer(File.read(File.join(@root, 'descendant')))
    # A killed orphan can remain a zombie until init reaps it; it cannot retain the pipe.
    assert_operator receipt.fetch('finished_at') - receipt.fetch('started_at'), :<, 2
    Process.kill('KILL', pid)
  rescue Errno::ESRCH
    nil
  end

  private

  def assert_protected_marker = assert_equal 'protected', File.read(File.join(@root, 'verified'))

  def assert_private_receipt(receipt)
    assert_equal 0, receipt.fetch('exit_code')
    assert_equal 'test-controller', receipt.fetch('clock_id')
    assert_equal "private evidence\n", File.read(verifier_log)
    assert_equal "sha256:#{Digest::SHA256.file(verifier_log).hexdigest}", receipt.fetch('output_digest')
    assert_equal 0o600, File.stat(verifier_log).mode & 0o777
  end

  def verify(body, seconds: 2)
    Shaka::Evaluation::ProtectedVerification.new(environment: { 'VERIFIER_MARKER' => 'protected' }).run(
      command: [RbConfig.ruby, '-e', body], cwd: @root, directory: File.join(@root, 'verification'),
      seconds:, clock_id: 'test-controller'
    )
  end

  def verifier_log = File.join(@root, 'verification', 'output.log')

  def wait_for_verification
    lines = native_stream.lines
    "STDOUT.sync=true; print #{lines.first(2).join.dump}; " \
      "sleep 0.01 until File.exist?('release'); print #{lines.drop(2).join.dump}"
  end
end
