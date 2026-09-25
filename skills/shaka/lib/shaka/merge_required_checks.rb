# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Refuses a merge unless GitHub reports every required check passing.
  module MergeRequiredChecks
    private

    def verify_checks(checks)
      raise Error, 'No observable required checks; native readiness is unknown' unless checks.is_a?(Array)
      if checks.empty?
        raise Error, 'GitHub reported no required checks on this branch. Merge refuses that empty ' \
                     'set. If the branch is unprotected, enable branch protection; if required ' \
                     'checks have not registered yet, wait and retry. This is not unread evidence.'
      end

      checks.each do |check|
        next if passing_check?(check)

        raise Error, "Required check is not passing or is malformed: #{check.inspect}"
      end
    end

    def passing_check?(check)
      return false unless check.is_a?(Hash) && check['name'].is_a?(String) && !check['name'].strip.empty?

      case check['state']
      when 'SUCCESS' then check['bucket'] == 'pass'
      when 'NEUTRAL', 'SKIPPED' then check['bucket'] == 'skipping'
      else false
      end
    end
  end
end
