# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'

module CursorUsageFixture
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  HOOK = File.expand_path('../skills/shaka/scripts/cursor-usage-hook', __dir__)
  COMMIT = 'a' * 40
  SESSION = '11111111-1111-4111-8111-111111111111'
  OTHER = '22222222-2222-4222-8222-222222222222'
  OLD = '00000000-0000-4000-8000-000000000001'
  NEW = '00000000-0000-4000-8000-000000000002'
  THIRD = '00000000-0000-4000-8000-000000000003'
  CLEAR = { 'CODEX_THREAD_ID' => nil, 'CLAUDE_CODE_SESSION_ID' => nil, 'CURSOR_CONVERSATION_ID' => nil }.freeze
  ROW = '| cursor | grok-4.6 | cursor-grok-4.6-medium | medium | 100 | 40 | 20 | UNKNOWN | 7 | UNKNOWN |'

  private

  def payload(generation, input, event: 'stop', conversation: SESSION)
    { conversation_id: conversation, generation_id: generation, model: 'cursor-grok-4.6-medium',
      model_id: 'grok-4.6', model_params: [{ id: 'effort', value: 'medium' }, { id: 'fast', value: 'false' }],
      hook_event_name: event, cursor_version: '3.20.21', input_tokens: input, output_tokens: 20,
      cache_read_tokens: 40, cache_write_tokens: 7, text: 'SENSITIVE-OUTPUT',
      user_email: 'SENSITIVE@example.com', transcript_path: '/private/SENSITIVE.jsonl' }
  end

  def stored(generation, input, event: 'stop', timestamp: '2026-09-16T12:00:00Z')
    payload(generation, input, event: event).except(:text, :user_email, :transcript_path).merge(timestamp: timestamp)
  end

  def write_records(directory, records, name: "#{SESSION}.jsonl")
    path = File.join(directory, name)
    File.write(path, "#{records.map { |record| JSON.generate(record) }.join("\n")}\n")
    path
  end

  def report(*, environment: {})
    output, error, status = Open3.capture3(CLEAR.merge(environment), COMMAND, 'usage', '--commit', COMMIT,
                                           '--contribution', 'implementation', *)
    assert status.success?, error
    output
  end

  def latest_and_duplicate(directory)
    write_records(directory, [stored(OLD, 900, timestamp: '2026-09-16T11:00:00Z'),
                              stored(NEW, 100), stored(NEW, 100, event: 'afterAgentResponse')])
  end
end

class CursorUsageTest < Minitest::Test
  include CursorUsageFixture

  def test_counts_each_generation_once_from_the_latest_turn
    Dir.mktmpdir do |directory|
      output = report('--host', 'cursor', '--file', latest_and_duplicate(directory))
      assert_includes output, ROW
      assert_includes output, '| cursor | grok-4.6 | medium | UNKNOWN | $0.000260 |'
      assert_includes output, '1 responses'
      assert_includes output, 'Cursor source versions: 3.20.21'
      assert_includes output.split('<details>').first, 'latest generation only'
      refute_match(/900|SENSITIVE/, output)
    end
  end

  def test_discovers_the_conversation_file
    Dir.mktmpdir do |directory|
      write_records(directory, [stored(OLD, 900), stored(NEW, 100)])
      env = { 'CURSOR_CONVERSATION_ID' => SESSION, 'CURSOR_USAGE_DIR' => directory }
      discovered = report(environment: env)
      assert_includes discovered, '| 100 | 40 | 20 | UNKNOWN | 7 | UNKNOWN |'
      refute_includes discovered, SESSION
    end
  end

  def test_selects_all_or_explicit_turns
    Dir.mktmpdir do |directory|
      file = write_records(directory, [stored(OLD, 900), stored(NEW, 100)])
      assert_includes report('--host', 'cursor', '--file', file, '--all-turns'), '| 1000 |'
      assert_includes report('--host', 'cursor', '--file', file, '--turn', OLD), '| 900 |'
    end
  end

  def test_each_file_contributes_its_latest_generation
    Dir.mktmpdir do |directory|
      first = write_records(directory, [stored(OLD, 900), stored(NEW, 100)])
      second = write_records(directory, [stored(THIRD, 200)], name: "#{OTHER}.jsonl")
      output = report('--host', 'cursor', '--file', first, '--file', second)
      assert_includes output, '| 300 | 80 | 40 | UNKNOWN | 14 | UNKNOWN |'
      refute_includes output, '| 900 |'
    end
  end

  def test_hook_omits_private_hook_fields
    Dir.mktmpdir do |directory|
      env = CLEAR.merge('CURSOR_USAGE_DIR' => directory)
      _out, err, status = Open3.capture3(env, HOOK, stdin_data: JSON.generate(payload(NEW, 100)))
      assert status.success?, err
      saved = File.read(File.join(directory, "#{SESSION}.jsonl"))
      refute_match(/SENSITIVE/, saved)
      assert_equal NEW, JSON.parse(saved.lines.first)['generation_id']
    end
  end

  def test_hook_records_are_readable_by_the_usage_command
    Dir.mktmpdir do |directory|
      env = CLEAR.merge('CURSOR_USAGE_DIR' => directory)
      Open3.capture3(env, HOOK, stdin_data: JSON.generate(payload(NEW, 100)))
      output = report('--host', 'cursor', '--file', File.join(directory, "#{SESSION}.jsonl"))
      assert_includes output, ROW
      refute_includes output, 'SENSITIVE'
    end
  end
end

class CursorUsageFailuresTest < Minitest::Test
  include CursorUsageFixture

  def test_missing_token_fields_stay_unknown_without_zero_inflation
    Dir.mktmpdir do |directory|
      incomplete = stored(NEW, 100)
      incomplete.delete(:cache_read_tokens)
      file = write_records(directory, [payload('33333333-3333-4333-8333-333333333333', 9900, event: 'preToolUse'),
                                       incomplete])
      output = report('--host', 'cursor', '--file', file)
      assert_includes output, '| medium | 100 | UNKNOWN | 20 | UNKNOWN | 7 | UNKNOWN |'
      refute_includes output, '9900'
    end
  end

  def test_discovery_ignores_another_conversation
    Dir.mktmpdir do |directory|
      write_records(directory, [stored(NEW, 100)], name: "#{OTHER}.jsonl")
      env = { 'CURSOR_CONVERSATION_ID' => SESSION, 'CURSOR_USAGE_DIR' => directory }
      assert_includes report(environment: env), 'Responses: UNKNOWN'
    end
  end

  def test_unreadable_lines_are_disclosed_without_dropping_valid_rows
    Dir.mktmpdir do |directory|
      file = write_records(directory, [stored(NEW, 100)])
      File.write(file, "{broken\n#{File.read(file)}")
      output = report('--host', 'cursor', '--file', file)
      assert_includes output, '| 100 |'
      assert_includes output, 'Unreadable or unidentifiable records'
    end
  end

  def test_hook_ignores_non_stop_payloads_and_empty_stdin
    Dir.mktmpdir do |directory|
      env = CLEAR.merge('CURSOR_USAGE_DIR' => directory)
      Open3.capture3(env, HOOK, stdin_data: JSON.generate(payload(NEW, 1, event: 'preToolUse')))
      Open3.capture3(env, HOOK, stdin_data: '')
      refute File.exist?(File.join(directory, "#{SESSION}.jsonl"))
    end
  end
end
