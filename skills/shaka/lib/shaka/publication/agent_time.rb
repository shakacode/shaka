# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'managed_region'
require_relative 'run_summary'
require_relative 'timeline_steps'

module Shaka
  # Where the agent's own time went in each chat session that updated this description: model time,
  # each kind of tool call, and time spent waiting on a person. Each session's latest totals are kept
  # in a hidden line, so an update from another session or machine adds to them. Only totals by fixed
  # category are published; the session is named by a hash, and no command or prompt text is kept. The running
  # session's totals arrive in the timeline from AgentTimeSession, so this module reads no transcript.
  module AgentTime
    HIDDEN = /^<!-- agent-time (\{.*\}) -->$/
    CATEGORIES = %w[validation review helper git_github shell files browser_mcp subagents other_tools].freeze
    LABELS = { 'model' => 'model', 'validation' => 'validation', 'review' => 'review', 'helper' => 'Shaka helper',
               'git_github' => 'git/GitHub', 'shell' => 'other shell', 'files' => 'files',
               'browser_mcp' => 'browser/MCP', 'subagents' => 'subagents', 'other_tools' => 'other tools' }.freeze
    HOSTS = ['Claude Code', 'Codex'].freeze
    MAX_SESSIONS = 10
    ID = /\A[0-9a-f]{16}\z/
    COUNTS = %w[active_ms model_ms waiting_ms between_turns_ms].freeze

    module_function

    def attach(timeline, pull)
      return timeline unless timeline && pull

      carried = TimelineSteps.same_repository?(pull) ? read(pull['body']) : []
      fresh = timeline['agent_time_current']
      sessions = (carried.reject { |entry| entry['id'] == fresh&.fetch('id') } + [fresh].compact)
      timeline.except('agent_time_current').merge('agent_time' => sessions.last(MAX_SESSIONS))
    end

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

    def identified?(entry) = entry.is_a?(Hash) && ID.match?(entry['id'].to_s) && HOSTS.include?(entry['host'])
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
