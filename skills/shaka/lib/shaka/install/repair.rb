# frozen_string_literal: true

require 'open3'
require_relative 'status'

module Shaka
  module Install
    # The install command's --repair flag.
    module RepairFlags
      private

      def repair_options(options)
        options.on('--repair', 'Run the steps install --status names that repair may run; deletes nothing') do
          @actions << :repair
        end
      end

      # False when a repair leaves the install unhealthy.
      def perform
        return Repair.new(source: @source, directory: @options[:directory]).call if @actions == [:repair]

        @actions == [:status] ? print_status : install
        true
      end
    end

    # Runs the next command install --status names, one problem at a time, for the states repair may
    # change. It stops at a healthy install, a decision, or a state outside that list. A second run
    # finds nothing to do. No step deletes a checkout, package, or file: a retired record is renamed.
    class Repair
      # Record a pull, finish an update, record Ruby, relink, retire an orphan record, keep local
      # commits on a branch, and unify a split install.
      REPAIRABLE = %w[B1 B7 B8 B9 C1 B2 C5].freeze
      LIMIT = 20

      def initialize(source:, directory: nil, home: Dir.home)
        @status = -> { Status.new(source:, directory:, home:) }
        @applied = []
      end

      # True when the install ends healthy.
      def call
        LIMIT.times do
          report = @status.call.call
          return healthy?(report) unless repairable?(report)

          apply(report)
        end
        raise ArgumentError, "Repair stopped after #{LIMIT} steps; run install --status"
      end

      private

      def repairable?(report) = REPAIRABLE.include?(report['state']) && report['next_command']

      # A step that leaves its own finding in place would repeat forever, so a repeat stops the repair.
      def apply(report)
        step = report.values_at('state', 'location', 'next_command')
        raise ArgumentError, "Repair did not clear #{step[0]} at #{step[1]}; run install --status" if
          @applied.include?(step)

        @applied << step
        puts "Repairing #{step[0]} at #{step[1]}: #{step[2]}"
        run(step)
      end

      def run(step)
        output, process = Open3.capture2e('sh', '-c', step[2])
        print output
        raise ArgumentError, "Repair step failed for #{step[0]}; run install --status" unless process.success?
      end

      def healthy?(report)
        puts 'Nothing to repair.' if @applied.empty?
        puts StatusText.render(report)
        report['severity'] == 'ok'
      end
    end
  end
end
