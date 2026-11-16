# frozen_string_literal: true

module Shaka
  # Explains, under Shaka metrics, a value the description could not show and how the next update fills it.
  module MissingValues
    SUMMARY = 'Missing values'
    # Watcher updates look for this to tell a body that carries the note from one published before it existed.
    HEADING = "<summary>#{SUMMARY}</summary>".freeze
    TASK_START = '- **Task start** was not recorded, so the cost line shows no time from task start to ready ' \
                 'or merge, and Timings shows Prompt to CI as not recorded. To fill it, the agent passes the ' \
                 'original request as `codex_task_start` or its timestamp as `task_started_at`.'

    module_function

    def detail(throughput)
      { 'summary' => SUMMARY, 'body' => TASK_START } unless ThroughputStats.task_started?(throughput)
    end
  end
end
