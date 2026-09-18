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
      MOVED = %w[R C].freeze

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

      # A rename and a copy carry a source field in either column; only a rename drops it.
      def record(entry, pending, result)
        codes = [entry[0], entry[1]]
        path = entry[PREFIX..].to_s
        return if path.empty?

        source = codes.intersect?(MOVED) ? pending.shift.to_s : nil
        result[:removed] << source if source && codes.include?('R')
        result[codes.include?('D') ? :removed : :added] << path
      end
    end
  end
end
