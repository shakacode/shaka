# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/codex_capture'
require_relative 'support/evaluation_capture_fixture'

class EvaluationCodexCaptureFailuresTest < Minitest::Test
  include EvaluationCaptureFixture

  def test_deadline_reaps_a_process_that_closed_its_output
    result = run_child("File.write('pid', Process.pid); STDOUT.close; STDERR.close; sleep 30", seconds: 0.3)
    assert_equal 'timed_out', result.fetch('transport_status')
    assert_nil result.fetch('terminal')
    refute_process(Integer(File.read(File.join(@root, 'pid'))))
  end

  def test_deadline_kills_and_reaps_a_child_that_ignores_term
    body = "Signal.trap('TERM', 'IGNORE'); File.write('pid', Process.pid); sleep 30"
    result = run_child(body, seconds: 0.3)
    assert_equal 'timed_out', result.fetch('transport_status')
    assert_nil result.fetch('terminal')
    refute_process(Integer(File.read(File.join(@root, 'pid'))))
  end

  def test_parent_exit_cleans_up_descendants_before_waiting_for_pipe_eof
    descendant = "3000.times { break if File.exist?('release-descendant'); sleep 0.01 }"
    body = "fork { #{descendant}; File.write('descendant-survived', 'bad') }; #{write_stream}"
    result = run_child(body)
    assert_equal 'completed', result.fetch('transport_status')
    assert_equal 'completed', result.fetch('native_status')
    refute result.fetch('command_capture_complete')
    File.write(File.join(@root, 'release-descendant'), 'go')
    sleep 0.3
    refute_path_exists File.join(@root, 'descendant-survived')
  end

  def test_termination_tolerates_a_group_left_with_only_zombies
    with_zombie_only_group do |leader|
      @capture.instance_variable_set(:@pid, leader)
      @capture.send(:terminate)
      assert_raises(Errno::ECHILD) { Process.waitpid(leader, Process::WNOHANG) }
    end
  end

  def test_descendants_are_cleaned_up_after_success_even_with_closed_pipes
    child = "STDOUT.close; STDERR.close; 500.times { break if File.exist?('release-child'); sleep 0.01 };"
    body = "fork { #{child} File.write('survived', 'bad') }; #{write_stream}"
    assert_equal 'completed', run_child(body).fetch('native_status')
    File.write(File.join(@root, 'release-child'), 'go')
    sleep 0.3
    refute_path_exists File.join(@root, 'survived')
  end

  def test_invalid_native_json_stops_the_child_and_retains_private_diagnostics
    body = "File.write('pid', Process.pid); STDOUT.sync=true; puts 'invalid'; sleep 30"
    assert_raises(IOError) { run_child(body) }
    assert_equal "invalid\n", File.read(private_log('stdout.jsonl'))
    refute_process(Integer(File.read(File.join(@root, 'pid'))))
  end

  def test_oversized_unterminated_stdout_is_refused
    assert_raises(IOError) { run_child("STDOUT.write('x' * 2_000_000); sleep 30") }
    assert_operator File.size(private_log('stdout.jsonl')), :<=, Shaka::Evaluation::CodexEvents::MAX_LINE + 16_384
  end

  def test_stderr_limit_prevents_unbounded_disk_retention
    assert_raises(IOError) { run_child("STDERR.write('x' * 10_000_000); sleep 30") }
    assert_operator File.size(private_log('stderr.log')), :<=, 8 * 1_048_576
  end

  def test_existing_output_directory_is_never_reused
    Dir.mkdir(@directory)
    File.write(private_log('stdout.jsonl'), 'keep')
    assert_raises(Errno::EEXIST) { run_child(write_stream) }
    assert_equal 'keep', File.read(private_log('stdout.jsonl'))
  end

  def test_spawn_failure_closes_the_pipes_without_a_capture_result
    assert_raises(Errno::ENOENT) do
      @capture.run(command: ['/no-such-codex'], cwd: @root, directory: @directory,
                   seconds: 1, clock_id: 'test-controller')
    end
  end
end
