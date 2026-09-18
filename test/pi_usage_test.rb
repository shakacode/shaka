# frozen_string_literal: true

require_relative 'test_helper'
require 'json'

module PiUsageFixture
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  COMMIT = 'a' * 40
  SESSION = '00000000-0000-4000-8000-000000000003'
  CLEAR = { 'PI_CODING_AGENT' => nil, 'PI_SESSION_ID' => nil, 'PI_SESSION_FILE' => nil,
            'CODEX_THREAD_ID' => nil, 'CLAUDE_CODE_SESSION_ID' => nil,
            'CURSOR_CONVERSATION_ID' => nil, 'OPENCODE_SESSION_ID' => nil }.freeze
  OLD_TURN = '33333333'
  ABANDONED_TURN = '55555555'
  CURRENT_TURN = '99999999'
  OLD_ROUTE = %w[observed-old routed-old].freeze
  ABANDONED_ROUTE = %w[observed-abandoned routed-abandoned].freeze
  CURRENT_ROUTE = %w[observed-new routed-new].freeze
  OLD_ROW = '| observed-old | configured-old | routed-old | high | 900 | 40 | 20 | UNKNOWN | 7 | 967 |'
  CURRENT_ROW = '| observed-new | configured-new | routed-new | low | 300 | 80 | 40 | UNKNOWN | 14 | 434 |'

  private

  def header(identity = SESSION)
    { type: 'session', version: 3, id: identity, timestamp: '2026-09-17T08:00:00.000Z',
      cwd: '/private/SENSITIVE-PATH' }
  end

  def entry(type, id, parent, **fields)
    { type: type, id: id, parentId: parent, timestamp: '2026-09-17T08:00:00.000Z', **fields }
  end

  def user(id, parent)
    entry('message', id, parent,
          message: { role: 'user', content: 'SENSITIVE-PROMPT', timestamp: 1_789_632_000_000 })
  end

  def assistant(id, parent, response, input, route)
    entry('message', id, parent,
          message: { role: 'assistant', responseId: response, provider: route.first, model: route.last,
                     content: [{ type: 'text', text: 'SENSITIVE-RESPONSE' }], timestamp: 1_789_632_000_000,
                     usage: { input: input, output: 20, cacheRead: 40, cacheWrite: 7,
                              reasoning: 5, totalTokens: input + 67 } })
  end

  def branched_session
    [header, *old_branch, *abandoned_branch, *current_branch]
  end

  def old_branch
    [entry('model_change', '11111111', nil, provider: 'selected-old', modelId: 'configured-old'),
     entry('thinking_level_change', '22222222', '11111111', thinkingLevel: 'high'),
     user(OLD_TURN, '22222222'), assistant('44444444', OLD_TURN, 'response-old', 900, OLD_ROUTE)]
  end

  def abandoned_branch
    [user(ABANDONED_TURN, '44444444'),
     assistant('66666666', ABANDONED_TURN, 'response-abandoned', 800, ABANDONED_ROUTE)]
  end

  def current_branch
    [entry('model_change', '77777777', '44444444', provider: 'selected-new', modelId: 'configured-new'),
     entry('thinking_level_change', '88888888', '77777777', thinkingLevel: 'low'), user(CURRENT_TURN, '88888888'),
     assistant('aaaaaaaa', CURRENT_TURN, 'response-current-1', 100, CURRENT_ROUTE), tool_result,
     assistant('cccccccc', 'bbbbbbbb', 'response-current-2', 200, CURRENT_ROUTE)]
  end

  def tool_result
    entry('message', 'bbbbbbbb', 'aaaaaaaa',
          message: { role: 'toolResult', toolCallId: 'private-call', toolName: 'bash',
                     content: [{ type: 'text', text: 'SENSITIVE-TOOL-OUTPUT' }], isError: false,
                     timestamp: 1_789_632_000_000 })
  end

  def write_session(directory, records, name: 'session.jsonl', raw_tail: '')
    file = File.join(directory, name)
    File.write(file, "#{records.map { |record| JSON.generate(record) }.join("\n")}\n#{raw_tail}")
    file
  end

  def report(*, environment: {})
    output, error, status = Open3.capture3(CLEAR.merge(environment), COMMAND, 'usage', '--commit', COMMIT,
                                           '--contribution', 'implementation', *)
    assert status.success?, error
    output
  end

  def discovered(file, identity: SESSION, extra: {})
    report(environment: { 'PI_CODING_AGENT' => 'true', 'PI_SESSION_ID' => identity,
                          'PI_SESSION_FILE' => file, **extra })
  end

  def assert_active_rows(output)
    assert_includes output, OLD_ROW
    assert_includes output, CURRENT_ROW
    assert_includes output, '3 responses'
    refute_match(/800|abandoned/, output)
  end

  def assert_unavailable(file)
    output = report('--host', 'pi', '--file', file, '--all-turns')
    assert_includes output, 'Responses: UNKNOWN'
    assert_includes output, 'Unreadable or unidentifiable records'
    refute_match(/999|SENSITIVE|deadbeef/, output)
  end
end

class PiUsageTest < Minitest::Test
  include PiUsageFixture

  def test_detects_pi_before_inherited_codex_context_and_uses_latest_active_branch_turn
    Dir.mktmpdir do |directory|
      output = discovered(write_session(directory, branched_session),
                          extra: { 'CODEX_THREAD_ID' => '00000000-0000-4000-8000-000000000099' })
      assert_includes output, CURRENT_ROW
      assert_includes output, '2 responses'
      assert_includes output, 'Pi source versions: 3'
      assert_includes output, 'latest user turn on the active branch'
      refute_match(/800|900|SENSITIVE|response-|private-call|#{Regexp.escape(SESSION)}/, output)
    end
  end

  def test_explicit_and_all_turns_never_include_abandoned_branches
    Dir.mktmpdir do |directory|
      file = write_session(directory, branched_session)
      explicit = report('--host', 'pi', '--file', file, '--turn', OLD_TURN, '--turn', CURRENT_TURN)
      all = report('--host', 'pi', '--file', file, '--all-turns')
      [explicit, all].each { |output| assert_active_rows(output) }
    end
  end

  def test_repeated_sources_count_each_response_once
    Dir.mktmpdir do |directory|
      file = write_session(directory, branched_session)
      output = report('--host', 'pi', '--file', file, '--file', file, '--all-turns')
      assert_includes output, '3 responses'
      assert_includes output, '| 300 | 80 | 40 | UNKNOWN | 14 | 434 |'
    end
  end
end

class PiUsageFailuresTest < Minitest::Test
  include PiUsageFixture

  def test_ephemeral_pi_evidence_does_not_fall_back_to_codex
    output = report(environment: { 'PI_CODING_AGENT' => 'true',
                                   'CODEX_THREAD_ID' => '00000000-0000-4000-8000-000000000099' })
    assert_unknown_pi(output)
  end

  def test_mismatched_pi_session_identity_is_unknown
    Dir.mktmpdir do |directory|
      file = write_session(directory, branched_session)
      assert_unknown_pi(discovered(file, identity: '00000000-0000-4000-8000-000000000099'))
    end
  end

  def test_missing_parent_makes_the_tree_unavailable
    Dir.mktmpdir do |directory|
      records = branched_session
      records.last[:parentId] = 'deadbeef'
      assert_unavailable(write_session(directory, records))
    end
  end

  def test_duplicate_entry_identity_makes_the_tree_unavailable
    Dir.mktmpdir do |directory|
      records = branched_session
      records << assistant('aaaaaaaa', CURRENT_TURN, 'SENSITIVE-CONFLICT', 999, CURRENT_ROUTE)
      assert_unavailable(write_session(directory, records))
    end
  end

  def test_malformed_json_makes_the_tree_unavailable
    Dir.mktmpdir do |directory|
      file = write_session(directory, branched_session, raw_tail: '{"SENSITIVE-INCOMPLETE"')
      assert_unavailable(file)
    end
  end

  def test_conflicting_response_copies_are_unknown
    Dir.mktmpdir do |directory|
      changed = Marshal.load(Marshal.dump(branched_session))
      changed.last[:message][:usage][:input] = 999
      first = write_session(directory, branched_session, name: 'first.jsonl')
      second = write_session(directory, changed, name: 'second.jsonl')
      output = report('--host', 'pi', '--file', first, '--file', second)
      assert_includes output, 'Conflicting response copies'
      assert_includes output, '| UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |'
    end
  end

  private

  def assert_unknown_pi(output)
    assert_includes output, 'Pi source versions: UNKNOWN'
    assert_includes output, 'Responses: UNKNOWN'
    refute_includes output, 'Codex source versions'
    refute_includes output, '| 300 |'
  end
end
