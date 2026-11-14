# frozen_string_literal: true

require 'digest'
require 'json'
require 'time'
require_relative 'agent_time_reader'
require_relative 'managed_region'
require_relative 'run_summary'
require_relative 'timeline_steps'
require_relative '../usage/claude_usage'
require_relative '../usage/codex_usage'

module Shaka
  # Where the agent's own time went in each chat session that updated this description: model time,
  # each kind of tool call, and time spent waiting on a person. Each session's latest totals are kept
  # in a hidden line, so an update from another session or machine adds to them. Only totals by fixed
  # category are published; the session is named by a hash, and no command or prompt text is kept.
  module AgentTime
    HIDDEN = /^<!-- agent-time (\{.*\}) -->$/
    CATEGORIES = %w[validation review helper git_github shell files browser_mcp subagents other_tools].freeze
    LABELS = { 'model' => 'model', 'validation' => 'validation', 'review' => 'review', 'helper' => 'Shaka helper',
               'git_github' => 'git/GitHub', 'shell' => 'other shell', 'files' => 'files',
               'browser_mcp' => 'browser/MCP', 'subagents' => 'subagents', 'other_tools' => 'other tools' }.freeze
    HOSTS = { 'Claude Code' => ClaudeUsage, 'Codex' => CodexUsage }.freeze
    MAX_SESSIONS = 10
    ID = /\A[0-9a-f]{16}\z/
    COUNTS = %w[active_ms model_ms waiting_ms between_turns_ms].freeze

    module_function

    def attach(timeline, pull, env: ENV)
      return timeline unless timeline && pull

      carried = TimelineSteps.same_repository?(pull) ? read(pull['body']) : []
      fresh = current(timeline['task_started_at'] || timeline['first_commit'], env, pull)
      sessions = (carried.reject { |entry| entry['id'] == fresh&.fetch('id') } + [fresh].compact)
      timeline.merge('agent_time' => sessions.last(MAX_SESSIONS))
    end

    # The session running this update, read from its own transcript since the task started. Without a
    # start, the transcript may hold earlier tasks, so nothing is read. A transcript that cannot be read
    # adds nothing, and the sessions already carried stay.
    def current(since, env, pull)
      return unless since

      HOSTS.each do |host, reader|
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
      CATEGORIES.filter_map { |category| [category, totals[category]] if totals[category]&.positive? }.to_h
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

    def read(body)
      line = Publishing.managed_region(body).to_s[HIDDEN, 1]
      data = line ? JSON.parse(line) : {}
      data.is_a?(Hash) ? Array(data['sessions']).filter_map { |entry| checked(entry) }.last(MAX_SESSIONS) : []
    rescue JSON::ParserError
      []
    end

    # Carried sessions come from an editable body, so every field is checked before it renders.
    def checked(entry)
      return unless identified?(entry)

      counts = entry.slice(*COUNTS)
      tools = entry['tools'].is_a?(Hash) ? entry['tools'].slice(*CATEGORIES) : {}
      return unless counts.size == COUNTS.size && [*counts.values, *tools.values].all? { |value| count?(value) }

      entry.slice('id', 'host').merge(counts, 'tools' => tools)
    end

    def identified?(entry) = entry.is_a?(Hash) && ID.match?(entry['id'].to_s) && HOSTS.key?(entry['host'])
    # A total over a year is not a measurement; dropping it keeps the renderer's arithmetic finite.
    def count?(value) = value.is_a?(Integer) && value.between?(0, 365 * 24 * 3_600_000)

    def hidden(sessions)
      "<!-- agent-time #{JSON.generate('sessions' => sessions)} -->" if sessions.any?
    end

    # "**Agent time:** 2h 10m working in 2 sessions: model 1h 20m · validation 25m · …"
    def summary(sessions)
      return if sessions.empty?

      total = ->(key) { duration(sessions.sum { |entry| entry[key] }) }
      count = sessions.size == 1 ? '1 session' : "#{sessions.size} sessions"
      "**Agent time:** #{total.call('active_ms')} working in #{count}: #{breakdown(sessions)}. " \
        "Waiting on a person: #{total.call('waiting_ms')} on questions, " \
        "#{total.call('between_turns_ms')} between turns."
    end

    # Model time and each tool category of at least a second, largest first.
    def breakdown(sessions)
      kept = totals(sessions).select { |_name, value| value >= 1000 }.sort_by { |_name, value| -value }
      kept.map { |name, value| "#{LABELS.fetch(name)} #{duration(value)}" }.join(' · ')
    end

    def totals(sessions)
      tools = CATEGORIES.to_h { |category| [category, sessions.sum { |entry| entry['tools'].fetch(category, 0) }] }
      { 'model' => sessions.sum { |entry| entry['model_ms'] }, **tools }
    end

    def duration(milliseconds) = RunSummary.duration(milliseconds)
  end
end
