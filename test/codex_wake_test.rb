# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/hosts/codex_wake'

class CodexWakeTest < Minitest::Test
  THREAD = '11111111-2222-4333-8444-555555555555'
  HEAD = 'a' * 40
  NOW = Time.iso8601('2026-10-07T04:00:00Z')

  def test_active_same_chat_registration_is_accepted_for_the_exact_pr
    assert_equal 'wake-trial', validate(packet)
  end

  def test_shell_output_and_failed_or_paused_registration_are_not_native_evidence
    invalid = ['SHAKA_WAKE checks', {}, packet.merge('registration' => { 'status' => 'ACTIVE' })]
    %w[PAUSED FAILED].each do |status|
      data = packet
      data['registration']['status'] = status
      invalid << data
    end
    invalid.each { |data| assert_raises(Shaka::Error) { validate(data) } }
  end

  def test_readback_must_match_the_registered_id_active_status_kind_and_chat
    { 'id' => 'different', 'status' => 'PAUSED', 'kind' => 'cron',
      'target_thread_id' => 'another-chat' }.each do |key, value|
      data = packet
      data['readback'][key] = value
      assert_raises(Shaka::Error, key) { validate(data) }
    end
  end

  def test_the_registration_cannot_cover_another_pr_or_moved_head
    { 'repository' => 'other/repo', 'number' => 42.0, 'head' => 'b' * 40 }.each do |key, value|
      assert_raises(Shaka::Error, key) { validate(packet.merge(key => value)) }
    end
    assert_raises(Shaka::Error) { validate(packet, head: nil) }
    assert_raises(Shaka::Error) { validate(packet, thread: nil) }
    assert_raises(Shaka::Error) { validate(packet, thread: '-' * 36) }
  end

  def test_expired_or_unbounded_registration_falls_back_instead_of_excusing_a_label
    ['2026-10-07T03:59:00Z', '2026-10-07T06:00:00Z', 'garbage', '2026-10-07T04:05:00', nil].each do |expiry|
      assert_raises(Shaka::Error) { validate(packet.merge('expires_at' => expiry)) }
    end
    assert_raises(Shaka::Error) { validate(packet.reject { |key| key == 'deadline' }) }
  end

  def test_native_schedule_must_have_a_future_run_before_expiry
    ['FREQ=MINUTELY;INTERVAL=5', 'FREQ=MINUTELY;INTERVAL=5;COUNT=1',
     'FREQ=MINUTELY;INTERVAL=5;UNTIL=20261007T040600Z',
     'FREQ=MINUTELY;INTERVAL=5;UNTIL=20261007T040400Z',
     'FREQ=MINUTELY;INTERVAL=5;UNTIL=20261007T035900Z',
     'FREQ=MINUTELY;INTERVAL=5;UNTIL=20261307T040400Z',
     'FREQ=MINUTELY;INTERVAL=0;UNTIL=20261007T040400Z'].each do |rrule|
      data = packet
      data['readback']['rrule'] = rrule
      assert_raises(Shaka::Error, rrule) { validate(data) }
    end
  end

  def test_empty_codex_markers_allow_manual_handoff_and_mixed_hosts_fail_closed
    assert_nil Shaka::CodexWake.check({ woken_by: 'host monitor' }, 'owner/repo', 42,
                                      environment: { 'CODEX_THREAD_ID' => '' })
    Shaka::CodexWake::OTHER_HOSTS.each do |marker|
      environment = { 'CODEX_THREAD_ID' => THREAD, marker => 'other-host-session' }
      assert_raises(Shaka::Error) { Shaka::CodexWake.check({ woken_by: 'host monitor' }, 'owner/repo', 42, environment:) }
    end
    environment = { 'CODEX_THREAD_ID' => THREAD, 'PI_CODING_AGENT' => 'true' }
    assert_raises(Shaka::Error) { Shaka::CodexWake.check({ woken_by: 'host monitor' }, 'owner/repo', 42, environment:) }
    assert_nil Shaka::CodexWake.check({ woken_by: 'host monitor' }, 'owner/repo', 42, environment: {})
    assert_nil Shaka::CodexWake.check({}, 'owner/repo', 42, environment: { 'CODEX_THREAD_ID' => THREAD })
  end

  def test_codex_automatic_handoff_requires_a_packet_before_github_is_read
    error = assert_raises(Shaka::Error) do
      Shaka::CodexWake.check({ woken_by: 'shell watcher' }, 'owner/repo', 42,
                             environment: { 'CODEX_THREAD_ID' => THREAD })
    end
    assert_includes error.message, '--codex-wake'
  end

  def test_unreadable_or_malformed_packet_reports_unavailable_coverage
    [nil, 'SHAKA_WAKE checks'].each do |contents|
      with_packet_file(contents) do |options|
        assert_raises(Shaka::Error) { Shaka::CodexWake.check(options, 'owner/repo', 42) }
      end
    end
  end

  def test_a_saved_native_packet_can_be_checked_without_replacing_the_ask_label
    with_packet_file(JSON.generate(packet)) do |options|
      assert_equal 'wake-trial', Shaka::CodexWake.check(options, 'owner/repo', 42,
                                                        environment: { 'CODEX_THREAD_ID' => THREAD }, now: NOW)
    end
  end

  private

  def with_packet_file(contents)
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'registration.json')
      File.write(path, contents) if contents
      yield({ codex_wake: path, head: HEAD })
    end
  end

  def validate(data, head: HEAD, thread: THREAD)
    target = { 'repository' => 'owner/repo', 'number' => 42, 'head' => head }
    Shaka::CodexWake.validate(data, thread:, target:, now: NOW)
  end

  def packet
    { 'repository' => 'owner/repo', 'number' => 42, 'head' => HEAD,
      'expires_at' => '2026-10-07T04:05:00Z', 'deadline' => '2026-10-07T05:28:24Z',
      'registration' => { 'automationId' => 'wake-trial', 'mode' => 'create', 'status' => 'ACTIVE' },
      'readback' => { 'id' => 'wake-trial', 'kind' => 'heartbeat', 'status' => 'ACTIVE',
                      'target_thread_id' => THREAD, 'rrule' => 'FREQ=MINUTELY;INTERVAL=1;UNTIL=20261007T040400Z' } }
  end
end
