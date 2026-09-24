# frozen_string_literal: true

require_relative 'error'

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

      current = names(@github.api_list(path))
      stale = current.select { |name| attention?(name) && !name.casecmp?(wanted.to_s) }
      stale.each { |name| current = names(@github.api(path(name), method: 'DELETE', expected: Array)) }
      unless wanted.nil? || current.any? { |name| name.casecmp?(wanted) }
        current = names(@github.api(path, method: 'POST', fields: { labels: [wanted] }, expected: Array))
      end
      { 'state' => state, 'labels' => current.select { |name| attention?(name) } }
    end

    private

    def path(label = nil) = ["repos/#{@github.repository}/issues/#{@github.number}/labels", label].compact.join('/')

    def attention?(name) = LABELS.value?(name.downcase)

    def names(labels)
      valid = labels.all? { |label| label.is_a?(Hash) && label['name'].is_a?(String) }
      raise Error, 'GitHub returned malformed labels.' unless valid

      labels.map { |label| label['name'] }
    end
  end
end
