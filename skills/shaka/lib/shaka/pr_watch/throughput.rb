# frozen_string_literal: true

require_relative '../publication/throughput_stats'

module Shaka
  class PrWatch
    # Fills CI to ready from GitHub check timestamps. It rewrites only the marked stats block.
    class ThroughputPublisher
      QUERY = <<~GRAPHQL
        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) {
            pullRequest(number: $number) { headRefOid
              commits(last: 50) { totalCount nodes { commit { oid
                status { contexts { context state createdAt } }
                checkSuites(first: 20) { pageInfo { hasNextPage } nodes { createdAt
                  checkRuns(first: 40) { pageInfo { hasNextPage }
                    nodes { name conclusion status startedAt completedAt } } } } } } } } } }
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
        2.times do
          times = @github.check_times
          next unless (pull = timeline) && same_head?(pull)

          carried = ThroughputStats.read(body = description_body)
          return unless carried

          updated = ThroughputStats.update(body, changes(pull, required, carried, times))
          return if updated == body
          next unless safe_to_write?(body)

          return write(updated)
        end
      end

      private

      def safe_to_write?(body) = description_body == body && same_head?(timeline)

      def timeline
        owner, name = @github.repository.split('/')
        found = @github.graphql(QUERY, { owner:, name:, number: @github.number }).dig('repository', 'pullRequest')
        raise Error, 'GitHub did not report the pull request for throughput.' unless found.is_a?(Hash)

        found
      end

      def changes(pull, required, carried, times)
        commits, total = commit_page(pull)
        heads, suites_complete = ThroughputStats.ci_heads(commits, required:, review_jobs: @review_jobs)
        ready = ThroughputStats.ready_at(times, required:, review_jobs: @review_jobs, wait: @wait)
        fields(commits, heads, ready, history_complete?(suites_complete, total, commits), carried)
      end

      def fields(commits, heads, ready, complete, carried)
        result = { 'head' => @head, 'rounds' => complete ? ThroughputStats.rounds(heads) : nil }
        result['t2'] = ready_stamp(ready, carried) if ready
        head = commits.find { |commit| commit.is_a?(Hash) && commit['oid'] == @head }
        prompt = ThroughputStats.prompt_stamp(head)
        result['t1'] = ThroughputStats.keep_earlier(prompt, carried, 't1', @head) if prompt
        push = ThroughputStats.bounded_first_push(heads, complete, carried)
        result['first_push'] = push if push
        result
      end

      def ready_stamp(ready, carried)
        seen = ready == :unknown ? 'UNKNOWN' : ready.utc.iso8601
        ThroughputStats.keep_earlier(seen, carried, 't2', @head)
      end

      def same_head?(pull) = pull.is_a?(Hash) && pull['headRefOid'] == @head

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
