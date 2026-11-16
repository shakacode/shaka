# frozen_string_literal: true

require_relative '../call_log'
require_relative 'machine_facts'
require_relative 'phase_log'
require_relative 'tree_watch'
require_relative 'trusted_command'

module Shaka
  module Evidence
    # Runs a fixed command while watching the tested tree, and returns its outcome with how long it took,
    # on what machine, and the phases the command reported into the file its environment names.
    module TimedCheck
      module_function

      def run(context, tree, path:, arguments:)
        (outcome, timing), phases = PhaseLog.with_file do |log|
          command = [{ 'PATH' => path, PhaseLog::VARIABLE => log }, File.join(*context.values_at(:root, :path)),
                     *arguments]
          TrustedCommand.around(context, tree) do |root, watched|
            MachineFacts.measure { CallLog.measure { TreeWatch.new(command, root:, tree: watched).run } }
          end
        end
        [outcome, CallLog.phases(phases) ? timing.merge('phases' => phases) : timing]
      end
    end
  end
end
