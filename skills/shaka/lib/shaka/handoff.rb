# frozen_string_literal: true

require_relative 'attention'
require_relative 'error'
require_relative 'merge_queue_commit'
require_relative 'merge_required_checks'
require_relative 'status'
require_relative 'handoff/conversation'
require_relative 'handoff/review_threads'
require_relative 'handoff/squash_note'
require_relative 'handoff/walkthrough'
require_relative 'handoff/wip_note'
require_relative 'post_implementation/evidence'

module Shaka
  # Reports what an agent still owes a PR before it ends a turn, and what a resumed session finds.
  # It reads only; the agent settles each owed item and runs it again.
  class Handoff
    include MergeRequiredChecks

    OWED_EXIT = 2
    SHORT = 7

    # A Stop hook or script can refuse to end the turn on this status without parsing the report.
    def self.exit_status(result) = result.fetch('owed').empty? ? 0 : OWED_EXIT

    def initialize(github, seam_required_checks: nil, post_implementation: nil)
      @github = github
      @status = Status.new(github, seam_required_checks:)
      @checkpoint = PostImplementationEvidence.new(github, **post_implementation) if post_implementation
    end

    # woken_by names what will wake this session, such as a host PR monitor or a background watcher;
    # the PR then needs no attention label, because the agent, not a person, acts next.
    def call(head: nil, woken_by: nil)
      @woken_by = wake_source(woken_by)
      pr = @status.call
      live = pr.fetch('headRefOid')
      @owed = []
      @notes = []
      @labels = []
      @owed << "PR head moved to #{live}; reread the PR before stopping." if head && head != live
      facts = pr['state'] == 'OPEN' ? open_facts(pr, live) : []
      { 'status' => ["PR ##{@github.number} #{pr['state']} head #{live[0, SHORT]}", *facts].join(' · '),
        'owed' => @owed, 'notes' => @notes, 'head' => live, 'state' => pr['state'] }
    end

    private

    # A blank name, as from an unset variable in a wrapper, would silently excuse a missing label.
    def wake_source(name)
      return if name.nil?
      raise Error, '--woken-by needs a name for what will wake this session.' if name.strip.empty?

      name.strip
    end

    def open_facts(snapshot, live)
      checks = snapshot['requiredChecks']
      [attention_fact(checks), checks_fact(checks, snapshot['requiredChecksUnavailable']), threads_fact,
       comment_fact(snapshot), walkthrough_fact(live), checkpoint_fact(live), squash_fact(snapshot, live),
       wip_fact(live)].compact
    end

    # An unsubmitted review by this account outranks every other wait, because only its author can see it.
    def attention_fact(checks)
      @labels = Attention.new(@github).current
      walkthrough_reader.pending? ? pending_review_fact : label_fact(checks)
    end

    # One label names the one decision the PR waits on, so a missing label hides the PR from its searches.
    def label_fact(checks)
      return woken_fact if @woken_by
      return owe('no awaiting label', 'Set the attention label for what the PR waits on.') if @labels.empty?
      return owe(@labels.join('+'), "Keep exactly one attention label; found #{list}.") if @labels.length > 1

      if merge_requested? && !passing?(checks)
        @owed << 'awaiting-merge-approval is set while required checks are not all passing.'
      end
      @labels.first
    end

    # A wake source replaces the label: the agent acts next, so no person should see the PR in a queue.
    def woken_fact
      return "woken by #{@woken_by}" if @labels.empty?

      owe(@labels.join('+'), "Remove #{list}; #{@woken_by} wakes the agent, not a person.")
    end

    def checks_fact(checks, unavailable)
      return "required checks unavailable: #{unavailable}" if checks.nil?
      return 'no required checks' if checks.empty?

      counts = checks.map { |check| check['bucket'] }.tally.map { |bucket, count| "#{count} #{bucket}" }
      "required checks #{counts.join(', ')}"
    end

    # Judges each check with the merge gate's own test. An empty set passes, as Ask allows.
    def passing?(checks) = checks.is_a?(Array) && checks.all? { |check| passing_check?(check) }

    # Checked here because this helper's current code runs even for a session that loaded an older Finish.
    # A merge queue takes no message, so the agent passes on what the queue writes instead.
    def squash_fact(snapshot, live)
      return unless merge_requested?

      queue = MergeQueueCommit.for(@github, snapshot)
      return note('merge queue', queue.note) if queue

      head = SquashNote.new(@github).head
      message = "Publish squash commit message for #{live} in the checkpoint; use `squash-message` for opt-out."
      return owe('no squash message', message) unless head
      return "squash message #{head[0, SHORT]}" if head == live

      owe("squash message #{head[0, SHORT]}", "The squash commit message names #{head}; post one for #{live}.")
    end

    def checkpoint_fact(live)
      return unless @checkpoint && merge_requested?

      @checkpoint.call(live)
      "checkpoint #{live[0, SHORT]}"
    rescue Error => e
      owe('checkpoint owed', e.message)
    end

    def wip_fact(live)
      pull = @github.api("repos/#{@github.repository}/pulls/#{@github.number}")
      recheck_head(pull.dig('head', 'sha'), live)
      revision = WipNote.revision(pull['body'])
      return owe('no WIP', 'WIP Details is missing; publish it before stopping.') unless revision

      problem = WipDetails.owner_error(WipNote.value(pull['body'], 'owner'))
      return owe('WIP owner incomplete', problem) if problem
      return "WIP #{live[0, SHORT]}" if WipNote.head(revision) == live

      owe('WIP stale', "WIP Details names #{revision}, not #{live}; refresh it.")
    end

    # The final read also returns the head, so a push during the earlier reads cannot pass as current.
    def recheck_head(moved, live)
      @owed << "PR head moved to #{moved} while handoff read it; run it again." if moved && moved != live
    end

    def list = @labels.join(', ')

    def merge_requested? = @labels.any? { |label| label.casecmp?('awaiting-merge-approval') }

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
