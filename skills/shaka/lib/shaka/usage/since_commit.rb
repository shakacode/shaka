# frozen_string_literal: true

require 'open3'
require 'time'
require_relative '../error'

module Shaka
  # Narrows a shared native session to responses after a known prior-task commit.
  module UsageSinceCommit
    private

    def select_since_commit
      cutoff = commit_time(@options[:since_commit])
      @source.responses.select! do |_id, record|
        timestamp = record['timestamp']
        raise Error, '--since-commit needs a timestamp for every response.' unless timestamp.is_a?(String)

        Time.iso8601(timestamp) > cutoff
      rescue ArgumentError
        raise Error, '--since-commit needs a timestamp for every response.'
      end
    end

    def commit_time(sha)
      output, error, status = Open3.capture3('git', 'show', '-s', '--format=%cI', sha)
      raise Error, "Cannot read --since-commit #{sha}: #{error.strip}" unless status.success?

      Time.iso8601(output.strip)
    rescue ArgumentError
      raise Error, "Cannot read --since-commit #{sha}: invalid timestamp."
    end
  end
end
