# frozen_string_literal: true

require_relative 'delivery_github'
require_relative 'delivery_workflow_tree'
require_relative 'workflow_pins'

module Shaka
  module Evaluation
    # Native declarations at one immutable head; does not claim Actions executed.
    class DeliveryWorkflows
      include DeliveryWorkflowTree

      QUERY = <<~GRAPHQL
        query($owner: String!, $name: String!, $expression: String!) {
          repository(owner: $owner, name: $name) {
            nameWithOwner
            object(expression: $expression) {
              __typename oid
              ... on Tree { entries {
                name mode type oid
                object { __typename oid ... on Blob { isBinary isTruncated byteSize text } }
              } }
            }
          }
        }
      GRAPHQL

      def initialize(repository:, head:, github:, seconds: 30)
        raise ArgumentError, 'Expected a repository and full immutable head' unless
          repository.is_a?(String) && %r{\A[\w-]+/[\w.-]+\z}.match?(repository) && revision?(head)

        @repository = repository
        @head = head
        owner, name = repository.split('/')
        @variables = { 'owner' => owner, 'name' => name, 'expression' => "#{head}:.github/workflows" }
        @api = DeliveryGitHub.new(github:, seconds:)
      end

      def read
        api = @api.start_deadline
        tree = read_tree(api)
        result = declarations(native_entries(tree))
        api.seconds_left
        result.merge('repository' => @repository, 'head' => @head, 'tree_oid' => tree.fetch('oid'),
                     'observed_at' => Process.clock_gettime(Process::CLOCK_MONOTONIC))
      rescue KeyError, TypeError, NoMethodError, ArgumentError, JSON::ParserError
        unavailable
      end

      private

      def read_tree(api)
        response = JSON.parse(api.graphql(QUERY, @variables))
        unavailable if response.key?('errors')
        repository = response.fetch('data').fetch('repository')
        unavailable unless repository.fetch('nameWithOwner').casecmp?(@repository)
        repository.fetch('object')
      end

      def declarations(entries)
        blobs = {}
        pins = {}
        files = entries.select { workflow_entry?(it) }
        files.sort_by { it.fetch('name') }.each do |entry|
          path = ".github/workflows/#{entry.fetch('name')}"
          found = WorkflowPins.new(path).read(workflow_text(entry))
          blobs[path] = entry.fetch('oid')
          pins = pins.is_a?(Hash) && found.is_a?(Hash) ? pins.merge(found) : 'UNKNOWN'
        end
        { 'workflow_blobs' => blobs, 'pinned_actions' => pins }
      end

      def workflow_entry?(row) = row.fetch('type') == 'blob' && /\.ya?ml\z/.match?(row.fetch('name'))
      def unavailable = raise(IOError, 'Native workflow snapshot unavailable')
    end
  end
end
