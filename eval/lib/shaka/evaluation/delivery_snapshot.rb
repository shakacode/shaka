# frozen_string_literal: true

require_relative 'delivery_github'
require_relative 'delivery_checks'
require_relative 'delivery_blobs'

module Shaka
  module Evaluation
    # Protected GitHub observations; does not discover policy or qualify execution.
    class DeliverySnapshot
      include DeliveryChecks
      include DeliveryBlobs

      CHANGES = %w[ADDED DELETED RENAMED COPIED MODIFIED CHANGED].freeze

      QUERY = <<~GRAPHQL
        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) {
            nameWithOwner
            pullRequest(number: $number) {
              number state headRefOid baseRefOid merged mergeCommit { oid }
              headRepository { nameWithOwner }
              changedFiles
              files(first: 100) { totalCount pageInfo { hasNextPage } nodes { path changeType } }
            }
          }
        }
      GRAPHQL

      def initialize(plan, github:, seconds: 30)
        @repository = plan.fetch('repository')
        @number = plan.fetch('number')
        @head = plan.fetch('head')
        @checks = plan.fetch('check_apps').dup
        @seconds = seconds
        raise ArgumentError, 'Expected a pinned same-repository PR and declared check App IDs' unless valid_plan?

        owner, name = @repository.split('/')
        @variables = { 'owner' => owner, 'name' => name, 'number' => @number }
        @api = DeliveryGitHub.new(github:, seconds:)
      end

      def read
        Timeout.timeout(@seconds) { snapshot }
      rescue KeyError, TypeError, NoMethodError, ArgumentError, JSON::ParserError, Timeout::Error
        unavailable
      end

      private

      def snapshot
        initial = read_pull
        checks = read_checks
        blobs = read_blobs(initial.fetch('files').fetch('nodes'))
        final = read_pull
        unavailable unless initial.values_at('baseRefOid', 'files') == final.values_at('baseRefOid', 'files')
        { 'pull' => final.except('files', 'changedFiles', 'headRepository'), 'checks' => checks, 'blobs' => blobs,
          'changed_files' => blobs.filter_map { |path, blob| [path, blob['lines']] if blob.key?('lines') }.to_h,
          'observed_at' => Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end

      def valid_plan?
        %r{\A[\w-]+/[\w.-]+\z}.match?(@repository.to_s) && /\A[0-9a-f]{40}\z/.match?(@head.to_s) &&
          @number.is_a?(Integer) && @number.positive? && valid_checks?
      end

      def valid_checks?
        @checks.is_a?(Hash) && !@checks.empty? && @checks.size <= 100 && @checks.all? do |name, app|
          check_policy?(name, app)
        end
      end

      def check_policy?(name, app)
        name.is_a?(String) && !name.strip.empty? && app.is_a?(Integer) && app.positive?
      end

      def graphql(query, variables)
        response = JSON.parse(@api.graphql(query, variables))
        unavailable if response.key?('errors')
        response.fetch('data')
      end

      def read_pull
        repository = graphql(QUERY, @variables).fetch('repository')
        unavailable unless repository.fetch('nameWithOwner').casecmp?(@repository)
        pull = repository.fetch('pullRequest')
        unavailable unless pull_identity?(pull) && complete_files?(pull) && pull_state?(pull)
        pull.merge('repository' => repository.slice('nameWithOwner'))
      end

      def pull_identity?(pull)
        pull.values_at('number', 'headRefOid') == [@number, @head] &&
          pull.dig('headRepository', 'nameWithOwner')&.casecmp?(@repository) &&
          /\A[0-9a-f]{40}\z/.match?(pull.fetch('baseRefOid'))
      end

      def pull_state?(pull)
        state = pull.fetch('state')
        merged = state == 'MERGED'
        commit = pull.fetch('mergeCommit')
        %w[OPEN CLOSED MERGED].include?(state) && pull.fetch('merged') == merged &&
          (merged ? /\A[0-9a-f]{40}\z/.match?(commit.fetch('oid')) : commit.nil?)
      end

      def complete_files?(pull)
        files = pull.fetch('files')
        rows = files.fetch('nodes')
        complete_rows?(rows) && files.dig('pageInfo', 'hasNextPage') == false &&
          files.fetch('totalCount') == rows.size && pull.fetch('changedFiles') == rows.size &&
          rows.map { it.fetch('path') }.uniq.size == rows.size
      end

      def complete_rows?(rows)
        rows.is_a?(Array) && rows.size <= 100 && rows.all? do |row|
          row.fetch('path').is_a?(String) && !row['path'].empty? &&
            CHANGES.include?(row.fetch('changeType'))
        end
      end

      def unavailable = raise(IOError, 'Native delivery snapshot unavailable')
    end
  end
end
