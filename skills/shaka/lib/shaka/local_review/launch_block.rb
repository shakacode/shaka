# frozen_string_literal: true

require_relative '../doctor/cli_inventory'

module Shaka
  # Says once that no configured reviewer can start on this machine, so an agent stops probing
  # the rest of the list. A lookup that could not be checked still counts as a possible launch.
  module LocalReviewLaunchBlock
    LAUNCH_FAILURES = %w[executable_missing credentials_missing].freeze
    BLOCKED = 'no_reviewer_can_launch'
    GUIDANCE = 'No configured reviewer can start on this machine; do not try the others. ' \
               'If this host can open a fresh chat, review there with the implementation model. ' \
               'Otherwise run `shaka review check --head %<head>s --not-run-reason TEXT` and hand review ' \
               'to a session that can start a reviewer.'

    module_function

    # Takes the entries `Doctor::CliInventory#call` returns.
    def none_launchable?(entries)
      configured = entries.select { |entry| entry[:configured] }
      configured.any? && configured.none? { |entry| entry[:installed] || entry[:unchecked] }
    end

    def fields(head) = { 'review_blocked' => BLOCKED, 'guidance' => format(GUIDANCE, head:) }

    # Only a reviewer that could not start leads here; a reviewer that ran and failed is a different question.
    def mark(result, review:, root:)
      return result unless LAUNCH_FAILURES.include?(result['failure_stage'])
      return result unless none_launchable?(Doctor::CliInventory.new(root:, environment: ENV).call(review))

      result.merge(fields(result['head']))
    end
  end
end
