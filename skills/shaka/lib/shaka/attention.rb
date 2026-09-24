# frozen_string_literal: true

require_relative 'error'
require_relative 'public_comments/bounded_list'

module Shaka
  # Labels a pull request with the one decision it waits on, so GitHub's PR list shows it.
  class Attention
    LABELS = { 'answer' => 'awaiting-answer', 'merge' => 'awaiting-merge-approval' }.freeze
    STATES = [*LABELS.keys, 'none'].freeze

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

    private

    def path(label = nil) = ["repos/#{@github.repository}/issues/#{@github.number}/labels", label].compact.join('/')

    # Deletes every other attention label, then adds the wanted one when it is missing.
    def keep_only(wanted)
      current = current_labels
      current.select { |name| attention?(name) && !name.casecmp?(wanted.to_s) }.each do |name|
        @github.api(path(name), method: 'DELETE', expected: Array)
      end
      return if wanted.nil? || current.any? { |name| name.casecmp?(wanted) }

      @github.api(path, method: 'POST', fields: { labels: [wanted] }, expected: Array)
    end

    def current_labels
      labels = PublicComments::BoundedList.new(@github, max_pages: 10, label: 'Label list').call(path)
      raise Error, 'GitHub returned malformed labels.' unless labels.all? { |label| label['name'].is_a?(String) }

      labels.map { |label| label['name'] }
    end

    def attention?(name) = LABELS.value?(name.downcase)
  end
end
