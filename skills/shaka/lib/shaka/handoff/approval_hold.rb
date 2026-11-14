# frozen_string_literal: true

require_relative '../status'

module Shaka
  # Names required checks held for a deployment approval. Such a check does not finish while it waits for a
  # person, so a monitor that waits for checks does not fire and cannot stand in for a label.
  module HandoffApprovalHold
    private

    # A held check voids --woken-by, so the label rule applies and only one way out is owed.
    def held?(checks) = held_checks(checks).any?

    def held_checks(checks) = Array(checks).select { |check| check['blocked'] == Status::APPROVAL_HOLD }

    def held_fact(checks)
      held = held_checks(checks)
      return if held.empty?

      fact = "blocked (#{Status::APPROVAL_HOLD}): #{held.map { |check| check['name'] }.join(', ')}"
      held.each { |check| record_hold(fact, check) }
      fact
    end

    # Under --woken-by the hold is owed, because nothing else will wake the agent; otherwise it is named.
    def record_hold(fact, check)
      link = check['link'].to_s.strip
      approve = "#{check['name']} waits on a manual approval; ask a person to approve it at " \
                "#{link.empty? ? 'its workflow run' : link}"
      return note(fact, "#{approve}.") unless @woken_by

      owe(fact, "#{approve}, or set awaiting-resume and run handoff without --woken-by: " \
                'a monitor that waits for checks will not wake while it is held.')
    end
  end
end
