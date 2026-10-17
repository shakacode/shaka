# frozen_string_literal: true

require 'digest'
require 'fileutils'
require_relative 'budget_limits'
require_relative 'run_record'

module Shaka
  module Evaluation
    # The executor supplies normalized records from native evidence, never agent-written accounting.
    class RecordStore
      def initialize(directory)
        @directory = directory
      end

      def write(record, id:, task:)
        raise BudgetError, 'Invalid executor record' unless valid?(record, id, task)

        FileUtils.mkdir_p(@directory, mode: 0o700)
        path = File.join(@directory, "#{id}.json")
        persist(record, path)
        "sha256:#{Digest::SHA256.file(path).hexdigest}"
      end

      private

      def valid?(record, id, task)
        RunRecord.errors(record).empty? && record['trial_id'] == id && record['task'] == task
      end

      def persist(record, path)
        File.open(path, 'wbx', 0o600) do |file|
          file.write(JSON.pretty_generate(record))
          file.flush
          file.fsync
        end
        File.open(@directory, File::RDONLY, &:fsync)
      end
    end
  end
end
