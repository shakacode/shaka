# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_capture'
require_relative 'support/evaluation_capture_fixture'

class EvaluationCodexCaptureTest < Minitest::Test
  include EvaluationCaptureFixture

  def test_live_pipes_preserve_split_utf8_and_drain_stderr_without_deadlock
    script = "data=#{native_stream.dump}; data.bytes.each_slice(7) { STDOUT.write(it.pack('C*')); STDOUT.flush };"
    result = run_child("STDERR.write('x' * 100_000); #{script}")
    assert_equal 'completed', result.fetch('transport_status')
    assert_equal '日本語 🌊', result.dig('terminal', 'text')
    assert_equal native_stream.b, File.binread(private_log('stdout.jsonl'))
    assert_equal 100_000, File.size(private_log('stderr.log'))
  end

  def test_live_receipt_keeps_source_digest_without_delivery_acceptance
    result = run_child(write_stream)
    assert_equal "sha256:#{Digest::SHA256.hexdigest(native_stream)}", result.fetch('stream_digest')
    refute result.fetch('command_capture_complete')
    refute result.fetch('terminal').key?('accepted_at')
  end

  def test_receipt_times_follow_live_arrival_order
    result = run_child(write_stream)
    times = result.fetch('events').map { it.fetch('received_at') }
    assert_equal times.sort, times
    assert_operator times.last, :<=, result.fetch('observed_at')
    assert_equal([1, 2, 3, 4], result.fetch('events').map { it.fetch('ordinal') })
  end

  def test_only_selected_environment_is_visible_and_raw_files_are_private
    run_child("warn [ENV.fetch('CAPTURE_MARKER'), ENV.key?('HOME')].join(':'); #{write_stream}")
    assert_equal "selected:false\n", File.read(private_log('stderr.log'))
    assert_equal 0, File.stat(@directory).mode & 0o077
    %w[stdout.jsonl stderr.log].each { assert_equal 0, File.stat(private_log(it)).mode & 0o077 }
  end

  def test_final_valid_json_record_without_newline_is_read_at_eof
    script = "STDOUT.write(#{native_stream.chomp.dump})"
    assert_equal 'completed', run_child(script).fetch('native_status')
  end

  def test_nonzero_exit_and_missing_completion_cannot_supply_terminal
    result = run_child("#{write_stream} exit 7")
    assert_equal 7, result.fetch('exit_code')
    assert_equal 'failed', result.fetch('native_status')
    assert_nil result.fetch('terminal')
  end

  def test_a_zero_exit_without_native_completion_is_incomplete
    result = run_child("puts JSON.generate(type: 'thread.started', thread_id: 'native')")
    assert_equal 0, result.fetch('exit_code')
    assert_equal 'incomplete', result.fetch('native_status')
    assert_nil result.fetch('terminal')
  end
end
