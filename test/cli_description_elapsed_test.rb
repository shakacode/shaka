# frozen_string_literal: true

require_relative 'cli_description_decisions_test'
require_relative 'publication_test'
require 'shaka/publication/published_timing'

# With no supplied start and no running watch, a description update still works out the time to ready.
class CliDescriptionElapsedTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes
  include CliDescriptionDecisionsRun

  COMMAND = CliDescriptionDecisionsTest::COMMAND
  ROOT = CliDescriptionDecisionsTest::ROOT
  SUMMARY = 'The time to ready shows without a watch.'
  THREAD = '11111111-1111-4111-8111-111111111111'
  TURN = '22222222-2222-4222-8222-222222222222'
  CHECKS = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass', 'completedAt' => '2026-10-18T08:10:00Z' },
            { 'name' => 'claude-review', 'state' => 'SUCCESS', 'bucket' => 'pass',
              'completedAt' => '2026-10-18T08:30:00Z' }].freeze

  def test_the_usage_report_and_green_checks_supply_the_time_to_ready
    assert_includes published('PR_CHECKS' => JSON.generate(CHECKS)), '· ready in 1h 30m'
  end

  def test_an_unreadable_check_list_still_publishes
    assert_includes published, '· ready pending'
    assert_equal 'pending', @timing['status']
  end

  def test_the_selected_codex_turn_replaces_the_usage_fallback_and_is_verified
    @codex_start = { 'thread_id' => THREAD, 'turn_id' => TURN }
    body = published('PR_CHECKS' => JSON.generate(CHECKS), 'PR_HEAD_REPO' => 'fork/repo')
    assert_includes body, '· ready in 2h 29m'
    assert_equal({ 'status' => 'verified', 'metric' => 'ready in 2h 29m' }, @timing)
    assert_includes body, '"task_started_at":"2026-10-18T06:00:00.750000000Z"'
    refute_includes body, THREAD
    refute_includes body, TURN
  end

  def test_an_unavailable_codex_turn_reports_the_lookup_gap_and_keeps_the_fallback
    @codex_start = { 'thread_id' => THREAD, 'turn_id' => THREAD }
    assert_includes published('PR_CHECKS' => JSON.generate(CHECKS)), '· ready in 1h 30m'
    assert_equal 'unavailable', @timing['status']
    assert_equal 'Selected Codex turn timestamp unavailable.', @timing['reason']
  end

  def test_a_codex_turn_after_pr_opening_keeps_the_fallback
    @codex_start = { 'thread_id' => THREAD, 'turn_id' => TURN }
    body = published('PR_CHECKS' => JSON.generate(CHECKS), 'PR_CREATED_AT' => '2026-10-18T05:59:00Z')
    assert_includes body, '· ready in 1h 30m'
    assert_equal 'Selected Codex turn is after PR opening.', @timing['reason']
  end

  def test_a_fork_refresh_does_not_verify_readiness_from_its_previous_body
    earlier_body = published('PR_CHECKS' => JSON.generate(CHECKS))
    fork_body = published('PR_HEAD_REPO' => 'fork/repo', 'EXISTING_BODY' => earlier_body)
    assert_includes fork_body, '· ready pending'
    assert_equal 'pending', @timing['status']
  end

  def test_the_stored_metric_is_verified_separately_from_the_timestamps
    body = published('PR_CHECKS' => JSON.generate(CHECKS))
    state = Shaka::ThroughputStats.read(body)
    result = Shaka::PublishedTiming.check(body.sub('· ready in 1h 30m', '· ready in 2h 0m'), expected: state)
    assert_equal 'unverified', result['status']
    assert_equal 'Stored elapsed time does not match the timing record.', result['reason']
  end

  def description_content
    record = USAGE_RECORD.merge('from' => '2026-10-18T07:00:00Z', 'covers_task' => true,
                                'columns' => [PublicationRegressionTest::USAGE_COLUMN])
    super.merge('usage' => { 'note' => 'Native usage is PARTIAL.', 'records' => [record] }).tap do |content|
      content['codex_task_start'] = @codex_start if @codex_start
    end
  end

  private

  def published(env = {})
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        codex_home = write_codex_session(dir) if @codex_start
        output, error, status = run_description(dir, root:, decisions: [], env: env.merge('CODEX_HOME' => codex_home))
        assert_predicate status, :success?, error
        @timing = JSON.parse(output).fetch('timing')
        return File.read(File.join(dir, 'published.md'))
      end
    end
  end

  def write_codex_session(dir)
    folder = File.join(dir, 'sessions/2026/10/18')
    FileUtils.mkdir_p(folder)
    File.write(File.join(folder, "rollout-#{THREAD}.jsonl"), <<~JSON)
      {"type":"session_meta","payload":{"id":"#{THREAD}"}}
      {"type":"event_msg","timestamp":"2026-10-18T06:00:00.750Z","payload":{"type":"task_started","turn_id":"#{TURN}"}}
      {"type":"event_msg","timestamp":"2026-10-18T07:00:00Z","payload":{"type":"task_started","turn_id":"other-turn"}}
    JSON
    dir
  end

  def fake_gh = DESCRIPTION_GH
end
