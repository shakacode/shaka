# frozen_string_literal: true

module Shaka
  # Explains, under Shaka metrics, a value the description could not show and how the next update fills it.
  module MissingValues
    SUMMARY = 'Missing values'
    # Watcher updates look for this to tell a body that carries the note from one published before it existed.
    HEADING = "<summary>#{SUMMARY}</summary>".freeze
    COST_LINE = 'the cost line shows no time from task start to ready or merge'
    TIMINGS = 'Timings shows Prompt to CI as not recorded'
    TO_FILL = 'To fill it, the agent passes the time of the first request as `task_started_at` when it publishes ' \
              'the description.'

    module_function

    # Timings is named only when the description renders that section.
    def detail(throughput, timings:)
      return if ThroughputStats.task_started?(throughput)

      effects = timings ? "#{COST_LINE}, and #{TIMINGS}" : COST_LINE
      { 'summary' => SUMMARY, 'body' => "- **Task start** was not recorded, so #{effects}. #{TO_FILL}" }
    end
  end
end
