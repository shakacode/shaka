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
    NOT_FOUND = 404
    FORBIDDEN = 403
    # Another run created the label first.
    ALREADY_EXISTS = 422

    def initialize(github)
      @github = github
    end

    # pull is a GitHub snapshot carrying the PR's labels. Returns who chose Auto and when, read from
    # the PR's events rather than from the agent's account, or raises naming why the label does not count.
    def verify!(pull)
      present!(pull)
      event = latest_labeling
      raise refusal('GitHub lists no event adding it') unless event

      actor = event.dig('actor', 'login')
      permission = permission(actor)
      unless WRITER_PERMISSIONS.include?(permission)
        raise refusal("#{actor.inspect} added it without write access (#{permission || 'unknown'})")
      end

      { 'label' => NAME, 'labeled_by' => actor, 'labeled_at' => event['created_at'] }
    end

    # Gives the repository the label beside the merge wait, so a maintainer finds it with its meaning.
    # The wait is already labeled, so a failure is reported rather than raised.
    def ensure_repository_label
      @github.api("repos/#{@github.repository}/labels/#{NAME}")
      'present'
    rescue Error => e
      e.http_status == NOT_FOUND ? create : "failed: #{e.message}"
    end

    private

    def present!(pull)
      return if MergeHold.new([NAME]).label(MergeHold.new.names(pull))

      raise refusal('the PR does not carry it')
    end

    def refusal(reason)
      Error.new("#{NAME} does not choose Auto: #{reason}. Hand the PR back under Ask")
    end

    def latest_labeling
      events = PublicComments::BoundedList.new(@github, max_pages: 10, label: 'PR event list')
                                          .call("repos/#{@github.repository}/issues/#{@github.number}/events")
      events.reverse.find do |event|
        event['event'] == 'labeled' && event.dig('label', 'name').to_s.casecmp?(NAME)
      end
    rescue PublicComments::BoundedList::LimitError
      raise refusal('the PR has too many events to find who added it')
    end

    def permission(actor)
      return unless actor.is_a?(String)

      PublicComments::Writers.new(@github).permissions([actor])[actor]
    end

    def create
      fields = { name: NAME, color: COLOR, description: DESCRIPTION }
      @github.api("repos/#{@github.repository}/labels", method: 'POST', fields:)
      'created'
    rescue Error => e
      case e.http_status
      when ALREADY_EXISTS then 'present'
      when FORBIDDEN then "not_created: this account cannot create labels, so a maintainer creates #{NAME}"
      else "failed: #{e.message}"
      end
    end
  end
end
