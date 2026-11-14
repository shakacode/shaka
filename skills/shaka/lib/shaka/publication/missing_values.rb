# frozen_string_literal: true

module Shaka
  # Explains, under Shaka metrics, each value the description could not show and how the next update fills it.
  module MissingValues
    SUMMARY = 'Missing values'
    TASK_START = '**Task start** was not recorded, so Shaka cannot measure the time to ready or merge, or ' \
                 'Prompt to CI. To fill it, the agent passes ' \
                 '`task_started_at` from the initiating request when it publishes the description, or ' \
                 'reports implementation usage with `shaka usage --all-turns` or `--since-time`.'

    module_function

    def detail(throughput)
      reasons = [(TASK_START if throughput['t0'].nil?)].compact
      { 'summary' => SUMMARY, 'body' => reasons.map { |reason| "- #{reason}" }.join("\n") } unless reasons.empty?
    end
  end
end
