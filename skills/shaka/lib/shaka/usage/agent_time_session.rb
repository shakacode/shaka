# frozen_string_literal: true

require 'digest'
require_relative '../publication/agent_time_reader'
require_relative '../publication/agent_time'
require_relative 'claude_usage'
require_relative 'codex_usage'

module Shaka
  # The agent time of the chat session running a description update, read from that session's own Claude Code
  # or Codex transcript. Publication only renders the totals, so the transcript readers stay out of it.
  module AgentTimeSession
    READERS = { 'Claude Code' => ClaudeUsage, 'Codex' => CodexUsage }.freeze

    module_function

    # Adds the running session's totals under `agent_time_current`; publication merges them with carried sessions.
    def attach(timeline, pull, env: ENV)
      return timeline unless timeline && pull

      fresh = current(timeline['task_started_at'] || timeline['first_commit'], env, pull)
      fresh ? timeline.merge('agent_time_current' => fresh) : timeline
    end

    # Read since the task started. Without a start, the transcript may hold earlier tasks, so nothing is read.
    # A transcript that cannot be read adds nothing, and the sessions already carried stay.
    def current(since, env, pull)
      return unless since

      READERS.each do |host, reader|
        path = transcript(reader, env)
        next unless path

        entry = summarize(AgentTimeReader.read(path, since:))
        return entry&.merge('id' => id(path, pull), 'host' => host)
      end
      nil
    rescue SystemCallError, IOError, EncodingError, TypeError, ArgumentError
      nil
    end

    # The id tells sessions apart within one pull request; mixing in the pull request keeps two pull
    # requests from one chat from sharing an id that would link them.
    def id(path, pull) = Digest::SHA256.hexdigest([pull['url'], pull['number'], path].join("\0"))[0, 16]

    def transcript(reader, env)
      variable = reader == ClaudeUsage ? 'CLAUDE_CODE_SESSION_ID' : 'CODEX_THREAD_ID'
      reader.session_file(env[variable], environment: env)
    end

    def summarize(reader)
      turns = reader.turns
      return if turns.empty?

      waiting, working = reader.calls.partition { |call| call.first == 'waiting' }
      { **busy(turns, spans(waiting), spans(waiting + working)), 'tools' => by_category(working) }
    end

    # Time in turns, less questions to a person; model time is what is left when no call of any kind ran.
    def busy(turns, waiting, any_call)
      total = turns.sum { |turn| turn.to - turn.from }
      { 'active_ms' => ms(total - waiting), 'model_ms' => ms([total - any_call, 0].max), 'waiting_ms' => ms(waiting),
        'between_turns_ms' => ms(between(turns)) }
    end

    # Milliseconds per tool category, in the fixed category order.
    def by_category(calls)
      totals = calls.group_by(&:first).transform_values { |group| ms(spans(group)) }
      AgentTime::CATEGORIES.filter_map { |category| [category, totals[category]] if totals[category]&.positive? }.to_h
    end

    # Seconds covered by any of the calls, so parallel calls are not counted twice.
    def spans(calls) = merge(calls.map { |call| call[1..] }.sort).sum { |from, to| to - from }

    def merge(intervals)
      intervals.each_with_object([]) do |(from, to), merged|
        last = merged.last
        last && from <= last[1] ? last[1] = [last[1], to].max : merged << [from, to]
      end
    end

    # Only a gap that ends with a person's message waits on that person; a background wake does not.
    def between(turns)
      turns.each_cons(2).sum { |previous, following| following.prompted ? [following.from - previous.to, 0].max : 0 }
    end

    def ms(seconds) = (seconds * 1000).round
  end
end
