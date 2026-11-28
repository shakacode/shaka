# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_hold'
require_relative 'public_comments/bounded_list'
require_relative 'public_comments/writers'

module Shaka
  # The label a maintainer adds to choose Auto for one PR that waits under Ask. The choice covers the
  # PR, not one commit, so a later push keeps it and Auto's own gates decide each head. Nothing here
  # removes the label: only a maintainer takes the choice back.
  class MergeApprovalLabel
    NAME = 'merge-approved'
    COLOR = '0E8A16'
    DESCRIPTION = 'A maintainer chose Auto for this PR: the agent merges once every Auto gate passes'
    # GitHub's REST permission reports maintain as write. Triage may add labels, so it does not count.
    WRITER_PERMISSIONS = %w[write admin].freeze
    LABEL_CHANGES = %w[labeled unlabeled].freeze
    NOT_FOUND = 404
    FORBIDDEN = 403
    ALREADY_EXISTS = 422

    def initialize(github)
      @github = github
    end

    # pull is a GitHub snapshot carrying the PR's labels. Returns who chose Auto and when, read from
    # the PR's events rather than from the agent's account, or raises naming why the label does not count.
    def verify!(pull)
      present!(pull)
      event = latest_label_change
      raise refusal('GitHub lists no event adding it') unless event
      raise refusal('GitHub lists its removal after it was added') if event['event'] == 'unlabeled'

      actor = writer!(Hash.try_convert(event['actor'])&.fetch('login', nil))
      { 'label' => NAME, 'labeled_by' => actor, 'labeled_at' => added_at!(event) }
    end

    # Gives the repository the label beside the merge wait, so a maintainer finds it with its meaning.
    # The wait is already labeled, so a failure is reported rather than raised.
    def ensure_repository_label(creating: true)
      @github.api("repos/#{@github.repository}/labels/#{NAME}")
      'present'
    rescue Error => e
      return create if e.http_status == NOT_FOUND && creating

      "failed: #{e.message}"
    end

    # Raises when pull, a snapshot carrying the PR's labels, no longer shows the label.
    def present!(pull)
      return if MergeHold.new([NAME]).label(MergeHold.new.names(pull))

      raise refusal('the PR does not carry it')
    end

    private

    def refusal(reason)
      Error.new("#{NAME} does not choose Auto: #{reason}. Hand the PR back under Ask")
    end

    # The newest event that added or removed the label; a removal the snapshot has not caught up with counts.
    def latest_label_change = label_events.reverse.find { |event| change?(event) }

    def label_events
      PublicComments::BoundedList.new(@github, max_pages: 10, label: 'PR event list')
                                 .call("repos/#{@github.repository}/issues/#{@github.number}/events")
    rescue PublicComments::BoundedList::LimitError
      raise refusal('the PR has too many events to find who added it')
    rescue Error => e
      raise refusal("GitHub did not list who added it (#{e.message})")
    end

    # A label change whose label cannot be read might be this one, so it refuses rather than let an older
    # approval stand.
    def change?(event)
      return false unless LABEL_CHANGES.include?(event['event'])

      name = Hash.try_convert(event['label'])&.fetch('name', nil)
      raise refusal('GitHub listed a label change it did not name') unless name.is_a?(String) && !name.strip.empty?

      name.casecmp?(NAME)
    end

    def added_at!(event)
      time = event['created_at']
      return time if time.is_a?(String) && !time.empty?

      raise refusal('GitHub did not say when it was added')
    end

    def writer!(actor)
      permission = PublicComments::Writers.new(@github).permissions([actor])[actor] if actor.is_a?(String)
      return actor if WRITER_PERMISSIONS.include?(permission)

      raise refusal("#{actor.inspect} added it without write access (#{permission || 'unknown'})")
    end

    def create
      fields = { name: NAME, color: COLOR, description: DESCRIPTION }
      @github.api("repos/#{@github.repository}/labels", method: 'POST', fields:)
      'created'
    rescue Error => e
      case e.http_status
      # GitHub also answers 422 for a rejected create, so only a read confirms another run made it.
      when ALREADY_EXISTS then ensure_repository_label(creating: false)
      when FORBIDDEN then "not_created: this account cannot create labels, so a maintainer creates #{NAME}"
      else "failed: #{e.message}"
      end
    end
  end
end
