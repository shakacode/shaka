# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'
require 'shaka/publication/agent_time'

# Synthetic Claude Code and Codex transcripts for agent-time tests.
module AgentTimeFixture
  SESSION = '01234567-89ab-cdef-0123-456789abcdef'
  START = Time.utc(2026, 11, 8, 10)

  private

  def summarize(records, since: nil)
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'session.jsonl')
      File.write(path, records.map { |record| JSON.generate(record) }.join("\n"))
      Shaka::AgentTime.summarize(Shaka::AgentTimeReader.read(path, since:))
    end
  end

  def claude_records
    [user('10:00:00', 'Do the task'),
     tool_use('10:01:00', 't1', 'Bash', 'bin/validate'), result('10:03:00', 't1'),
     tool_use('10:04:00', 'q1', 'AskUserQuestion'), result('10:05:00', 'q1'),
     tool_use('10:06:00', 'r1', 'Read'), tool_use('10:06:00', 'r2', 'Grep'),
     result('10:06:20', 'r1'), result('10:06:30', 'r2'),
     assistant('10:10:00', 'end_turn'), { 'type' => 'system', 'timestamp' => '2026-11-08T10:59:00Z' },
     assistant('11:00:00', nil), assistant('11:01:00', 'end_turn')]
  end

  def at(clock) = "2026-11-08T#{clock}Z"
  def user(clock, text) = { 'type' => 'user', 'timestamp' => at(clock), 'message' => { 'content' => text } }

  def assistant(clock, stop)
    { 'type' => 'assistant', 'timestamp' => at(clock),
      'message' => { 'stop_reason' => stop, 'content' => [{ 'type' => 'text', 'text' => 'ok' }] } }
  end

  def tool_use(clock, id, name, command = nil)
    { 'type' => 'assistant', 'timestamp' => at(clock),
      'message' => { 'content' => [{ 'type' => 'tool_use', 'id' => id, 'name' => name,
                                     'input' => { 'command' => command }.compact }] } }
  end

  def result(clock, id)
    { 'type' => 'user', 'timestamp' => at(clock),
      'message' => { 'content' => [{ 'type' => 'tool_result', 'tool_use_id' => id }] } }
  end

  def codex(time, type, payload) = { 'timestamp' => time, 'type' => type, 'payload' => payload }

  def write_transcript(home, records)
    directory = File.join(home, 'projects', 'project')
    FileUtils.mkdir_p(directory)
    lines = records.map { |record| JSON.generate(record.merge('sessionId' => SESSION)) }
    File.join(directory, "#{SESSION}.jsonl").tap { |path| File.write(path, lines.join("\n")) }
  end

  def carried_session
    { 'id' => 'f' * 16, 'host' => 'Codex',
      'active_ms' => 1, 'model_ms' => 1, 'waiting_ms' => 0, 'between_turns_ms' => 0, 'tools' => {} }
  end

  def body(sessions)
    "<!-- shaka:begin -->\n#{Shaka::AgentTime.hidden(sessions)}\n<!-- shaka:end -->"
  end

  def same_repository_pull(text)
    repo = { 'repo' => { 'full_name' => 'shakacode/shaka' } }
    { 'body' => text, 'head' => repo, 'base' => repo }
  end
end
