# frozen_string_literal: true

require_relative '../usage/journal'

module Shaka
  # Owes a usage snapshot for the head, so a later owner or host recovers this work's usage from the PR
  # instead of this machine's transcripts.
  module HandoffUsage
    # Why this host cannot publish a usage snapshot. A blank reason, as from an unset variable in a wrapper,
    # would silently excuse missing usage.
    def usage_gap=(reason)
      raise Error, '--usage-gap needs a reason.' if reason&.strip&.empty?

      @usage_gap = reason&.strip
    end

    private

    def record_facts(snapshot, live)
      [squash_fact(snapshot, live), closing_fact, wip_fact(live), usage_fact(live), rendering_fact(live)]
    end

    def usage_fact(live)
      return "usage #{live[0, Handoff::SHORT]}" if UsageJournal.new(@github).covers?(live)
      return note('usage gap', "No usage snapshot for #{live}: #{@usage_gap}") if @usage_gap

      owe('no usage snapshot', "Publish usage for #{live} with `usage publish #{@github.repository} " \
                               "#{@github.number} --commit #{live} --contribution CATEGORY --event handoff` and " \
                               "this task's source selection, or pass `--usage-gap REASON` when no measured response " \
                               'can be published, as for a host without a reader or an aggregate-only source.')
    # A gap excuses only a host with no reader; a journal no one can read still needs its comment repaired.
    rescue Error => e
      owe('usage unread', "Usage snapshots are unread: #{e.message}")
    end
  end
end
