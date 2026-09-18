# frozen_string_literal: true

require_relative '../error'

module Shaka
  class Snapshot
    # Reads `git status --porcelain -z` into the paths a snapshot must add and remove.
    #
    # The -z format gives each change as `XY path`, except a rename or copy, which is the
    # destination followed by its source as a separate field with no status prefix.
    class Changes
      PREFIX = 3

      def initialize(entries)
        @entries = entries.reject { |entry| entry.to_s.empty? }
      end

      def added = collect.fetch(:added).uniq.sort

      def removed = (collect.fetch(:removed) - collect.fetch(:added)).uniq.sort

      private

      def collect
        @collect ||= begin
          result = { added: [], removed: [] }
          pending = @entries.dup
          record(pending.shift, pending, result) until pending.empty?
          result
        end
      end

      def record(entry, pending, result)
        index = entry[0]
        worktree = entry[1]
        path = entry[PREFIX..].to_s
        return if path.empty?

        result[:removed] << pending.shift.to_s if %w[R C].include?(index)
        deleted = index == 'D' || worktree == 'D'
        result[deleted ? :removed : :added] << path
      end
    end
  end
end
