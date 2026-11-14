# frozen_string_literal: true

module Shaka
  # Explains, under Shaka metrics, each value the description could not show and how the next update fills it.
  module MissingValues
    SUMMARY = 'Missing values'
    TASK_START = '**Task start** was not recorded, so Shaka cannot measure the time to ready or merge, or ' \
                 'Prompt to CI. To fill it, the agent passes the time of the first request as ' \
                 '`task_started_at` when it publishes the description.'

    module_function

    def detail(throughput)
      reasons = [(TASK_START unless ThroughputStats.task_started?(throughput))].compact
      { 'summary' => SUMMARY, 'body' => reasons.map { |reason| "- #{reason}" }.join("\n") } unless reasons.empty?
    end
  end
end
