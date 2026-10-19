# frozen_string_literal: true

require 'time'
require_relative '../error'
require_relative '../attention'

module Shaka
  # Reads when the pull request opened, waited on a person, and closed, for the description's timings.
  class PullTimeline
    QUERY = <<~GRAPHQL
      query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $number) {
            createdAt mergedAt closedAt
            commits(first: 1) { nodes { commit { committedDate } } }
            timelineItems(first: 100, after: $cursor, itemTypes: [LABELED_EVENT, UNLABELED_EVENT]) {
              pageInfo { hasNextPage endCursor }
              nodes {
                __typename
                ... on LabeledEvent { createdAt label { name } }
                ... on UnlabeledEvent { createdAt label { name } }
              }
            }
          }
        }
      }
    GRAPHQL
    MAX_PAGES = 10

    def initialize(github)
      @github = github
    end

    # Returns the timeline, or why GitHub could not supply it, so a failed read never blocks publication.
    def call
      read_pages
    rescue Error, KeyError, TypeError, ArgumentError => e
      { 'unavailable' => e.message }
    end

    private

    def read_pages
      events = []
      cursor = nil
      MAX_PAGES.times do
        pull = page(cursor)
        items = pull['timelineItems']
        events.concat(label_events(items['nodes']))
        return timeline(pull, events) unless items.dig('pageInfo', 'hasNextPage')

        cursor = items.dig('pageInfo', 'endCursor')
      end
      raise Error, "The label timeline has more than #{MAX_PAGES} pages."
    end

    def page(cursor)
      owner, name = @github.repository.split('/')
      variables = { owner:, name:, number: @github.number, cursor: }
      pull = @github.graphql(QUERY, variables).dig('repository', 'pullRequest')
      return pull if pull.is_a?(Hash) && pull['timelineItems'].is_a?(Hash)

      raise Error, 'GitHub did not report the pull request timeline.'
    end

    def label_events(nodes)
      Array(nodes).grep(Hash).filter_map do |node|
        label = node.dig('label', 'name').to_s.downcase
        next unless Attention::LABELS.value?(label)

        { 'name' => label, 'added' => node['__typename'] == 'LabeledEvent', 'at' => Time.iso8601(node['createdAt']) }
      end
    end

    def timeline(pull, events)
      first = pull.dig('commits', 'nodes', 0, 'commit', 'committedDate')
      {
        'opened' => Time.iso8601(pull.fetch('createdAt')),
        'first_commit' => first && Time.iso8601(first),
        'merged' => pull['mergedAt'] && Time.iso8601(pull['mergedAt']),
        'closed' => pull['closedAt'] && Time.iso8601(pull['closedAt']),
        'labels' => events.sort_by { |event| event['at'] }
      }
    end
  end
end
