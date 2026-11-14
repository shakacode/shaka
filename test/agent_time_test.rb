# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'agent_time_fixture'
require 'shaka/publication/timings_details'

# A session's transcript becomes totals by fixed category.
class AgentTimeReaderTest < Minitest::Test
  include AgentTimeFixture

  def test_claude_turns_split_model_tool_and_waiting_time
    entry = summarize(claude_records)

    # Turn one runs 10:00:00 to 10:10:00, with a 2m validation, a 1m question, and parallel 30s file reads.
    # The second turn, woken after the first ended, runs 11:00:00 to 11:01:00 with no tools.
    # A background wake is not a person's reply, so the hour before it is not time between turns.
    assert_equal [600_000, 60_000, 450_000, 0],
                 entry.values_at('active_ms', 'waiting_ms', 'model_ms', 'between_turns_ms')
    assert_equal({ 'validation' => 120_000, 'files' => 30_000 }, entry['tools'])
  end

  def test_time_before_a_persons_next_message_counts_between_turns
    records = [user('10:00:00', 'First'), assistant('10:01:00', 'end_turn'), user('10:31:00', 'Second'),
               assistant('10:32:00', 'end_turn')]

    assert_equal 30 * 60_000, summarize(records)['between_turns_ms']
  end

  def test_a_host_wake_after_a_finished_turn_is_not_waiting_on_a_person
    records = [user('10:00:00', 'First'), assistant('10:01:00', 'stop_sequence'),
               user('10:51:00', '<task-notification>done</task-notification>'), assistant('10:52:00', 'end_turn')]

    entry = summarize(records)

    assert_equal [0, 120_000], entry.values_at('between_turns_ms', 'active_ms')
  end

  def test_a_tool_call_during_a_question_is_not_subtracted_twice
    records = [user('10:00:00', 'Go'), tool_use('10:04:00', 'q', 'AskUserQuestion'),
               tool_use('10:04:30', 'b', 'Bash', 'ls'), result('10:04:50', 'b'), result('10:05:00', 'q'),
               assistant('10:10:00', 'end_turn')]

    assert_equal [540_000, 540_000], summarize(records).values_at('active_ms', 'model_ms')
  end

  SHELL_CASES = {
    'git commit -m "fix rubocop"' => 'git_github', 'cd x && gh pr edit --body bin/validate' => 'git_github',
    'LANG=C bundle exec rubocop' => 'validation', 'sed -n 1,40p test/foo_test.rb' => 'shell',
    'gh pr edit 1 --body "tests; bundle exec rubocop passed"' => 'git_github', 'git status; rubocop' => 'validation',
    %q(gh pr edit 1 --body 'cmd:"bundle exec rubocop"') => 'git_github',
    'scripts/shaka description --body "ran bin/validate"' => 'helper', 'bash -lc "git status"' => 'git_github',
    '$H evidence run --command validate' => 'validation', 'timeout -s KILL 10 rspec' => 'validation',
    'nice -n 5 rubocop' => 'validation', 'timeout --signal KILL 10 rspec' => 'validation',
    'timeout -v 10 rspec' => 'validation', 'timeout -k 5 10 rspec' => 'validation',
    'timeout --kill-after 5 --signal 9 10 rspec' => 'validation', 'timeout --signal=KILL 10 rspec' => 'validation',
    "bash -lc 'bundle exec rspec' task-name" => 'validation',
    "bash -lc 'echo done' rubocop" => 'shell', 'go test ./...' => 'validation', 'eslint .' => 'validation',
    "bash -lc 'git status; bundle exec rubocop'" => 'validation', 'bundle exec ruby bin/validate' => 'validation',
    '$(git status)' => 'shell', "git commit -F - <<'EOF'\nfix\nrubocop cleanup\nEOF" => 'git_github',
    "cat <<EOF > notes\nbin/validate passed\nEOF\nbundle exec rspec" => 'validation',
    '${H} review run --head x' => 'review', "printf '%s\\n' '<<EOF'\nbundle exec rspec" => 'validation',
    %(gh pr edit --body "use <<EOF"\nbundle exec rspec) => 'validation',
    "cat <<< hello\nbundle exec rspec" => 'validation',
    "echo $((1<<3))\nbundle exec rspec" => 'validation',
    "cat <<'EOF' > \"note-$((1+1)).txt\"\nbundle exec rubocop\nEOF" => 'shell'
  }.freeze

  def test_shell_calls_are_classed_by_the_programs_they_run
    assert_equal(SHELL_CASES, SHELL_CASES.keys.to_h { |command| [command, Shaka::ToolCategory.call('Bash', command)] })
  end

  def test_codex_scripts_and_argument_lists_are_classed_by_their_commands
    script = 'text(await tools.exec_command({cmd:"pwd\\nbundle exec rubocop lib"}))'

    arrays = [['bash', '-lc', 'git status'], ['bash', '-lc', 'cd repo && bundle exec rubocop']]

    assert_equal %w[validation git_github validation],
                 [Shaka::ToolCategory.call('exec', script),
                  *arrays.map { |argv| Shaka::ToolCategory.call('exec_command', argv) }]
  end

  def test_a_message_sent_while_a_tool_runs_stays_in_the_turn
    records = [user('10:00:00', 'Go'), tool_use('10:00:00', 'b', 'Bash', 'ls'), user('10:02:00', 'Also this'),
               result('10:05:00', 'b'), assistant('10:06:00', 'end_turn')]

    assert_equal [0, 360_000], summarize(records).values_at('between_turns_ms', 'active_ms')
  end

  def test_an_image_only_message_is_a_persons_reply
    image = { 'type' => 'user', 'timestamp' => at('10:31:00'), 'message' => { 'content' => [{ 'type' => 'image' }] } }
    records = [user('10:00:00', 'First'), assistant('10:01:00', 'end_turn'), image, assistant('10:32:00', 'end_turn')]

    assert_equal 30 * 60_000, summarize(records)['between_turns_ms']
  end

  def test_an_out_of_order_record_never_shortens_a_turn
    records = [user('10:00:00', 'Go'), assistant('10:05:00', nil), assistant('09:59:00', nil),
               assistant('10:06:00', 'end_turn')]

    assert_equal 360_000, summarize(records)['active_ms']
  end

  def test_a_reminder_block_before_a_persons_text_is_still_their_message
    blocks = [{ 'type' => 'text', 'text' => '<system-reminder>x</system-reminder>' },
              { 'type' => 'text', 'text' => 'Go on' }]
    reply = { 'type' => 'user', 'timestamp' => at('10:31:00'), 'message' => { 'content' => blocks } }
    records = [user('10:00:00', 'First'), assistant('10:01:00', 'end_turn'), reply, assistant('10:32:00', 'end_turn')]

    assert_equal 30 * 60_000, summarize(records)['between_turns_ms']
  end

  def test_codex_local_shell_commands_are_categorized
    records = [codex('2026-11-08T10:00:00Z', 'event_msg', 'type' => 'task_started'),
               codex('2026-11-08T10:00:10Z', 'response_item', 'type' => 'local_shell_call', 'call_id' => 'c1',
                                                              'action' => { 'command' => %w[git status] }),
               codex('2026-11-08T10:00:20Z', 'response_item', 'type' => 'function_call_output', 'call_id' => 'c1')]

    assert_equal({ 'git_github' => 10_000 }, summarize(records)['tools'])
  end

  def test_codex_turns_and_calls_pair_by_call_id
    records = [codex('2026-11-08T10:00:00Z', 'event_msg', 'type' => 'task_started'),
               codex('2026-11-08T10:00:10Z', 'response_item', 'type' => 'function_call', 'call_id' => 'c1',
                                                              'name' => 'exec_command',
                                                              'arguments' => '{"cmd":"gh pr view 1"}'),
               codex('2026-11-08T10:00:40Z', 'response_item', 'type' => 'function_call_output', 'call_id' => 'c1'),
               codex('2026-11-08T10:01:00Z', 'event_msg', 'type' => 'task_complete')]

    entry = summarize(records)

    assert_equal 60_000, entry['active_ms']
    assert_equal({ 'git_github' => 30_000 }, entry['tools'])
  end

  def test_records_before_the_task_start_are_left_out
    entry = summarize(claude_records, since: Time.utc(2026, 11, 8, 10, 30))

    assert_equal 60_000, entry['active_ms']
    assert_empty entry['tools']
  end
end

# Only checked totals reach the description, and sessions carried there survive later updates.
class AgentTimeCarryTest < Minitest::Test
  include AgentTimeFixture

  def test_without_a_task_start_no_transcript_is_read
    with_session do |pull, env|
      assert_equal ['f' * 16], ids(Shaka::AgentTime.attach({}, pull, env:))
    end
  end

  def test_an_unreadable_transcript_keeps_the_carried_sessions
    with_session do |pull, env, path|
      File.chmod(0o000, path)
      assert_equal ['f' * 16], ids(Shaka::AgentTime.attach({ 'task_started_at' => START }, pull, env:))
    ensure
      File.chmod(0o600, path)
    end
  end

  def test_attach_reads_the_running_session_and_keeps_other_sessions
    with_session do |pull, env|
      pull['body'] = body([carried_session, carried_session.merge('id' => 'bad')])
      sessions = Shaka::AgentTime.attach({ 'task_started_at' => START }, pull, env:)['agent_time']

      assert_equal [%w[ffffffffffffffff Codex], 'Claude Code'],
                   [sessions.first.values_at('id', 'host'), sessions.last['host']]
      refute_includes JSON.generate(sessions), SESSION
    end
  end

  # One chat updating two pull requests must not give them a shared id that links them.
  def test_the_session_id_differs_per_pull_request
    with_session do |pull, env|
      first, second = [1, 2].map do |number|
        Shaka::AgentTime.attach({ 'task_started_at' => START }, pull.merge('number' => number), env:)
      end

      refute_equal first['agent_time'].last['id'], second['agent_time'].last['id']
    end
  end

  def test_a_malformed_transcript_line_adds_nothing_instead_of_failing
    call = { 'type' => 'tool_use', 'id' => 't', 'name' => 'Bash', 'input' => 'x' }
    odd = { 'type' => 'user', 'timestamp' => at('10:00:30'),
            'message' => { 'content' => [{ 'type' => 'text', 'text' => 5 }] } }
    records = [{ 'type' => 'user', 'timestamp' => at('10:00:00'), 'message' => 'x' }, odd,
               { 'type' => 'assistant', 'timestamp' => at('10:01:00'), 'message' => { 'content' => [call] } }]

    assert_equal 60_000, summarize(records)['active_ms']
  end

  def test_carried_sessions_with_bad_fields_are_dropped
    good = { 'id' => 'a' * 16, 'host' => 'Codex',
             'active_ms' => 5, 'model_ms' => 4, 'waiting_ms' => 0, 'between_turns_ms' => 0,
             'tools' => { 'shell' => 1, 'secret' => 9 } }
    bad = [good.merge('host' => 'Other'), good.merge('active_ms' => -1), good.merge('tools' => { 'shell' => 'x' }),
           good.merge('model_ms' => 10**30)]

    sessions = Shaka::AgentTime.read(body([good, *bad]))

    assert_equal([{ 'shell' => 1 }], sessions.map { |entry| entry['tools'] })
  end

  def test_summary_ranks_categories_and_names_waits
    entry = summarize(claude_records).merge('id' => 'a' * 16, 'host' => 'Claude Code')

    assert_equal '**Agent time:** 10m working in 1 session: model 7m 30s · validation 2m 0s · files 30s. ' \
                 'Waiting on a person: 1m 0s on questions, 0s between turns.', Shaka::AgentTime.summary([entry])
  end

  private

  def with_session
    Dir.mktmpdir do |home|
      path = write_transcript(home, claude_records)
      env = { 'CLAUDE_CODE_SESSION_ID' => SESSION, 'CLAUDE_CONFIG_DIR' => home }
      yield same_repository_pull(body([carried_session])), env, path
    end
  end

  def ids(timeline) = timeline['agent_time'].map { |entry| entry['id'] }
end

# The agent-time line and its hidden carrier render in the Timings section.
class AgentTimeTimingsTest < Minitest::Test
  include AgentTimeFixture

  def test_timings_render_the_agent_time_line_and_its_hidden_record
    session = carried_session.merge('active_ms' => 120_000, 'model_ms' => 120_000)
    timeline = { 'opened' => START, 'merged' => START + 3600, 'labels' => [], 'agent_time' => [session] }

    body = Shaka::TimingsDetails.new(timeline).detail['body']

    assert_includes body, '**Agent time:** 2m 0s working in 1 session: model 2m 0s.'
    assert_equal([timeline['agent_time'].first['id']], Shaka::AgentTime.read(region(body)).map { |entry| entry['id'] })
  end

  private

  def region(body) = "<!-- shaka:begin -->\n#{body}\n<!-- shaka:end -->"
end
