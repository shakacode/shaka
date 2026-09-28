# frozen_string_literal: true

require_relative 'error'
require_relative 'public_comments/bounded_list'

module Shaka
  # Labels a pull request with the one decision it waits on, so GitHub's PR list shows it.
  class Attention
    LABELS = { 'answer' => 'awaiting-answer', 'merge' => 'awaiting-merge-approval',
               'resume' => 'awaiting-resume' }.freeze
    STATES = [*LABELS.keys, 'none'].freeze
    COLORS = { 'awaiting-answer' => 'F9A03F', 'awaiting-merge-approval' => '8250DF',
               'awaiting-resume' => '1D76DB' }.freeze
    DESCRIPTIONS = {
      'awaiting-answer' => 'The agent asked a question in chat and is waiting for your answer',
      'awaiting-merge-approval' => 'Ready under Ask: merge this commit or approve it so the agent merges',
      'awaiting-resume' => 'Paused with nothing to wake the agent; resume from WIP Details'
    }.freeze
    NOT_FOUND = 404
    # 403: the caller may apply labels but not create them. 422: another run created it first.
    TOLERATED_CREATE_FAILURES = [403, 422].freeze

    def initialize(github)
      @github = github
    end

    def call(state:)
      raise Error, "State must be one of: #{STATES.join(', ')}." unless STATES.include?(state)

      wanted = LABELS[state]
      raise Error, 'Pull request is not open.' if wanted && @github.snapshot['state'] != 'OPEN'

      keep_only(wanted)
      { 'state' => state, 'labels' => [wanted].compact }
    end

    # The attention labels the PR carries now, in GitHub's order.
    def current = current_labels.select { |name| attention?(name) }

    private

    def path(label = nil) = ["repos/#{@github.repository}/issues/#{@github.number}/labels", label].compact.join('/')

    # Deletes every other attention label, then adds the wanted one when it is missing.
    def keep_only(wanted)
      current = current_labels
      missing = wanted && current.none? { |name| name.casecmp?(wanted) }
      ensure_repository_label(wanted) if missing
      remove_other_attention_labels(current, wanted)
      @github.api(path, method: 'POST', fields: { labels: [wanted] }, expected: Array) if missing
    end

    def remove_other_attention_labels(current, wanted)
      current.select { |name| attention?(name) && !name.casecmp?(wanted.to_s) }.each do |name|
        @github.api(path(name), method: 'DELETE', expected: Array)
      end
    end

    # Gives a new repository label its color and description; an existing one keeps the maintainer's.
    # Without permission to create labels, the add-label call still runs and reports GitHub's answer.
    def ensure_repository_label(label)
      @github.api("repos/#{@github.repository}/labels/#{label}")
    rescue Error => e
      raise unless e.http_status == NOT_FOUND

      create(label)
    end

    def create(label)
      fields = { name: label, color: COLORS.fetch(label), description: DESCRIPTIONS.fetch(label) }
      @github.api("repos/#{@github.repository}/labels", method: 'POST', fields: fields)
    rescue Error => e
      raise unless TOLERATED_CREATE_FAILURES.include?(e.http_status)
    end

    def current_labels
      labels = PublicComments::BoundedList.new(@github, max_pages: 10, label: 'Label list').call(path)
      raise Error, 'GitHub returned malformed labels.' unless labels.all? { |label| label['name'].is_a?(String) }

      labels.map { |label| label['name'] }
    end

    def attention?(name) = LABELS.value?(name.downcase)
  end
end
