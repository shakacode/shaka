# frozen_string_literal: true

require_relative 'attention'
require_relative 'public_comments/bounded_list'
require_relative 'status'
require_relative 'walkthrough_history'
require_relative 'wip_details'

module Shaka
  # Reports what an agent still owes a PR before it ends a turn, and what a resumed session finds.
  # It reads only; the agent settles each owed item and runs it again.
  class Handoff
    OWED_EXIT = 2
    SHORT = 7
    PASSING = %w[pass skipping].freeze

    # A Stop hook or script can refuse to end the turn on this status without parsing the report.
    def self.exit_status(result) = result.fetch('owed').empty? ? 0 : OWED_EXIT

    def initialize(github, seam_required_checks: nil)
      @github = github
      @status = Status.new(github, seam_required_checks:)
    end

    # woken_by names what will wake this session, such as a host PR monitor or a background watcher;
    # the PR then needs no attention label, because the agent, not a person, acts next.
    def call(head: nil, woken_by: nil)
      @woken_by = woken_by
      pr = @status.call
      live = pr.fetch('headRefOid')
      @owed = []
      @notes = []
      @owed << "PR head moved to #{live}; reread the PR before stopping." if head && head != live
      facts = pr['state'] == 'OPEN' ? open_facts(pr, live) : []
      { 'status' => ["PR ##{@github.number} #{pr['state']} head #{live[0, SHORT]}", *facts].join(' · '),
        'owed' => @owed, 'notes' => @notes, 'head' => live, 'state' => pr['state'] }
    end

    private

    def open_facts(snapshot, live)
      checks = snapshot['requiredChecks']
      [label_fact(checks), checks_fact(checks, snapshot['requiredChecksUnavailable']), walkthrough_fact(live),
       wip_fact(live)]
    end

    # One label names the one decision the PR waits on, so a missing label hides the PR from its searches.
    def label_fact(checks)
      labels = Attention.new(@github).current
      return "woken by #{@woken_by}" if labels.empty? && @woken_by
      return owe('no awaiting label', 'Set the attention label for what the PR waits on.') if labels.empty?
      return owe(labels.join('+'), "Keep exactly one attention label; found #{labels.join(', ')}.") if labels.length > 1

      if labels.first.casecmp?('awaiting-merge-approval') && !passing?(checks)
        @owed << 'awaiting-merge-approval is set while required checks are not all passing.'
      end
      labels.first
    end

    def checks_fact(checks, unavailable)
      return "required checks unavailable: #{unavailable}" if checks.nil?
      return 'no required checks' if checks.empty?

      counts = checks.map { |check| check['bucket'] }.tally.map { |bucket, count| "#{count} #{bucket}" }
      "required checks #{counts.join(', ')}"
    end

    def passing?(checks) = checks.is_a?(Array) && checks.all? { |check| PASSING.include?(check['bucket']) }

    def walkthrough_fact(live)
      revision = latest_walkthrough
      return note('no walkthrough', 'No walkthrough yet; one is required before merge.') unless revision
      return "walkthrough #{revision[0, SHORT]}" if revision == live

      owe("walkthrough #{revision[0, SHORT]}", "The walkthrough explains #{revision}; publish one for #{live}.")
    end

    # Superseded walkthroughs are wrapped in a pointer, so only the current one still renders as a walkthrough.
    # Only this account's reviews count, so a commenter's copied walkthrough cannot change what is owed.
    def latest_walkthrough
      path = "repos/#{@github.repository}/pulls/#{@github.number}/reviews"
      reviews = PublicComments::BoundedList.new(@github, max_pages: 5, label: 'Review listing').call(path)
      account = @github.api('user')['login']
      current = reviews.reverse.find do |review|
        review.dig('user', 'login') == account && review['state'] == 'COMMENTED' &&
          WalkthroughText.rendered?(review['body'].to_s)
      end
      current && WalkthroughText.revision(current['body'])
    end

    def wip_fact(live)
      pull = @github.api("repos/#{@github.repository}/pulls/#{@github.number}")
      moved = pull.dig('head', 'sha')
      @owed << "PR head moved to #{moved} while handoff read it; run it again." if moved && moved != live
      revision = WipDetails.revision(pull['body'])
      return owe('no WIP', 'WIP Details is missing; publish it before stopping.') unless revision
      return "WIP #{live[0, SHORT]}" if revision.include?(live)

      owe('WIP stale', "WIP Details names #{revision}, not #{live}; refresh it.")
    end

    def owe(fact, item)
      @owed << item
      fact
    end

    def note(fact, item)
      @notes << item
      fact
    end
  end
end
