# frozen_string_literal: true

require_relative '../publication/throughput_stats'

module Shaka
  class PrWatch
    # Fills CI to ready from GitHub check timestamps. It rewrites only the marked stats block.
    class ThroughputPublisher
      QUERY = <<~GRAPHQL
        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) {
            pullRequest(number: $number) {
              headRefOid
              commits(last: 50) {
                totalCount
                nodes {
                  commit {
                    oid
                    pushedDate
                    status { contexts { context state createdAt } }
                    checkSuites(first: 8) {
                      pageInfo { hasNextPage }
                      nodes {
                        checkRuns(first: 40) {
                          pageInfo { hasNextPage }
                          nodes { name conclusion status completedAt }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      def self.watch(arguments, head, jobs, settings)
        github = GitHub.new(*arguments)
        publisher = for_watch(github, head, jobs, settings)
        PrWatch.new(github, head:, ci_jobs: jobs, settings:, adapters: { throughput: publisher })
      end

      def self.for_watch(github, head, jobs, settings)
        new(github, head:, review_jobs: jobs, wait: settings[:ci_review_wait])
      end

      def initialize(github, head:, review_jobs:, wait:)
        @github = github
        @head = head
        @review_jobs = review_jobs
        @wait = wait
      end

      def call(required:)
        pull = timeline
        return unless pull['headRefOid'] == @head

        body = description_body
        carried = ThroughputStats.read(body)
        return unless carried

        updated = ThroughputStats.update(body, changes(pull, required, carried))
        write(updated) unless updated == body
      end

      private

      def timeline
        owner, name = @github.repository.split('/')
        found = @github.graphql(QUERY, { owner:, name:, number: @github.number }).dig('repository', 'pullRequest')
        raise Error, 'GitHub did not report the pull request for throughput.' unless found.is_a?(Hash)

        found
      end

      def changes(pull, required, carried)
        commits, total = commit_page(pull)
        heads, suites_complete = ThroughputStats.ci_heads(commits, required:, review_jobs: @review_jobs)
        ready = ThroughputStats.ready_at(@github.check_times, required:, review_jobs: @review_jobs, wait: @wait)
        fields(heads, ready, history_complete?(suites_complete, total, commits), carried)
      end

      def fields(heads, ready, complete, carried)
        result = { 'head' => @head, 'rounds' => complete ? ThroughputStats.rounds(heads) : nil }
        result['t2'] = stamp(ready) if ready
        push = ThroughputStats.bounded_first_push(heads, complete, carried)
        result['first_push'] = push if push
        result
      end

      def stamp(ready) = ready == :unknown ? 'UNKNOWN' : ready.utc.iso8601

      def history_complete?(suites_complete, total, commits)
        suites_complete && total.is_a?(Integer) && total == commits.size
      end

      def commit_page(pull)
        connection = pull['commits']
        return [[], nil] unless connection.is_a?(Hash)

        nodes = Array(connection['nodes'])
        [nodes.filter_map { |node| node['commit'] if node.is_a?(Hash) }, connection['totalCount']]
      end

      def description_body = @github.api(path).fetch('body').to_s

      def write(body) = @github.api(path, method: 'PATCH', fields: { body: })

      def path = "repos/#{@github.repository}/pulls/#{@github.number}"
    end
  end
end
