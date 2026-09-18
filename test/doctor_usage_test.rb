# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'

# A usage source counts only when this command can actually open it.
class DoctorUsageTest < Minitest::Test
  include DoctorHelper

  def test_a_missing_usage_source_degrades_without_blocking
    report, blocked = doctor(usage_files: [])
    assert_includes report, 'DEGRADED'
    refute blocked
  end

  # discover only locates sources, so a located-but-unreadable transcript is not healthy.
  def test_a_located_but_unreadable_usage_source_degrades
    report, blocked = doctor(usage_files: ['/definitely/missing/transcript.jsonl'])
    assert_includes report, 'DEGRADED'
    refute blocked
  end

  # An OpenCode session handle is not a file, so doctor cannot open it and must not claim it did.
  def test_a_session_handle_doctor_cannot_open_is_not_reported_as_ready
    report, blocked = doctor(usage_files: ['session:ses_example'])
    assert_includes report, 'DEGRADED'
    refute blocked
  end

  # Detection answers nil when several hosts are present, and a blank host is not a report.
  def test_an_ambiguous_host_is_named_rather_than_left_blank
    report, blocked = with_two_hosts { doctor(host: nil, usage_files: []) }
    assert_includes report, 'ambiguous'
    refute_match(/host +·/, report)
    refute blocked
  end

  # An empty transcript opens fine and still produces no usage rows.
  def test_an_empty_transcript_is_not_counted_as_a_usage_source
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'session.jsonl')
      File.write(path, '')
      report, blocked = doctor(usage_files: [path])
      assert_includes report, 'DEGRADED'
      refute blocked
    end
  end

  # A readable directory is not a transcript.
  def test_a_directory_is_not_counted_as_a_usage_source
    Dir.mktmpdir do |dir|
      report, blocked = doctor(usage_files: [dir])
      assert_includes report, 'DEGRADED'
      refute blocked
    end
  end

  private

  def with_two_hosts
    original = ENV.values_at('CODEX_THREAD_ID', 'CLAUDE_CODE_SESSION_ID')
    ENV['CODEX_THREAD_ID'] = 'thread'
    ENV['CLAUDE_CODE_SESSION_ID'] = 'session'
    yield
  ensure
    ENV['CODEX_THREAD_ID'], ENV['CLAUDE_CODE_SESSION_ID'] = original
  end
end
