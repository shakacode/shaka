# frozen_string_literal: true

require_relative 'error'
require_relative 'required_checks'

module Shaka
  # Refuses a merge unless every gating check (native, or seam-declared as a fallback) is passing.
  module MergeRequiredChecks
    EMPTY_REQUIRED_CHECKS = 'GitHub reported no required checks on this branch. Merge refuses that empty set. ' \
                            'If the branch is unprotected, enable branch protection or list merge.required_checks; ' \
                            'if required checks have not registered yet, wait and retry. ' \
                            'This is not unread evidence. In Ask mode, pass --empty-checks-confirmed-head for a head ' \
                            'the user told you to merge; Auto supplies no such approval.'

    private

    def verify_gate
      gate = RequiredChecks.new(@github, seam_names: @seam_required_checks).call
      verify_checks(gate.fetch('checks'), head: @head, confirmed_head: @empty_checks_confirmed_head)
      gate
    end

    # confirmed_head names the head a user told the agent to merge knowing no check gates it.
    def verify_checks(checks, head: nil, confirmed_head: nil)
      verify_all_checks(@github.checks, checks) if @auto
      raise Error, 'No observable required checks; native readiness is unknown' unless checks.is_a?(Array)
      return verify_empty_confirmation(head, confirmed_head) if checks.empty?

      checks.each do |check|
        next if passing_check?(check)

        raise Error, "Required check is not passing or is malformed: #{check.inspect}"
      end
    end

    # Under Auto, GitHub has to report CLEAN, as with ci_review_wait: all. Named base failures keep
    # GitHub at UNSTABLE, so they defer to the trusted wait: `none` and `one` accept UNSTABLE once
    # verify_all_checks has required every other check to pass, and `all` still requires CLEAN.
    def merge_state_wait
      return @ci_review_wait unless @auto

      @base_failures&.any? ? @ci_review_wait : 'all'
    end

    # Auto merges also need every reported check on the head, required or not, to have passed,
    # except a non-required one that MergeBaseFailures finds failing on the base branch too.
    def verify_all_checks(checks, required)
      raise Error, 'Head checks are unknown; Auto cannot merge' unless checks.is_a?(Array)

      waiting = unexcused(checks.reject { |check| passing_check?(check) }, required)
      return if waiting.empty?

      names = waiting.map { |check| check.is_a?(Hash) ? "#{check['name']} (#{check['state']})" : check.inspect }
      raise Error, "Auto merges only when every check on the head passed; not passing: #{names.join(', ')}. " \
                   'Wait with pr watch --auto, or hand the PR back under Ask'
    end

    # Drops the failures MergeBaseFailures finds on the base branch too. A check merge.required_checks
    # names counts as required even where GitHub's own required checks take that list's place.
    def unexcused(waiting, required)
      return waiting unless @base_failures

      if required.is_a?(Array)
        names = required.filter_map { |check| check['name'] if check.is_a?(Hash) }.union(Array(@seam_required_checks))
      end
      waiting - @base_failures.excuse(waiting, names, @target.base)
    end

    def verify_empty_confirmation(head, confirmed_head)
      raise Error, EMPTY_REQUIRED_CHECKS unless confirmed_head
      return if confirmed_head == head

      raise Error, "Empty-checks confirmation names #{confirmed_head}, not the current head #{head}; " \
                   'ask the user to confirm this head'
    end

    # Reported only when the confirmation excused an empty set, so a merge result shows no check gated it.
    def excused_checks(gate, head)
      gate.fetch('checks').empty? ? { 'empty_required_checks_confirmed_head' => head } : {}
    end

    # What the last check read excused as base failures, so the result names the base commit it verified.
    def base_failure_evidence = @base_failures ? @base_failures.evidence : {}

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
