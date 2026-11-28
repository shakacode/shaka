# frozen_string_literal: true

require_relative '../publication/throughput_stats'
require_relative '../publication/rendering_preview'

module Shaka
  class PrWatch
    # Fills the current head's check start, ready time, and merge time from GitHub. It rewrites only the marked stats
    # block and the spend after the model line.
    class ThroughputPublisher
      QUERY = <<~GRAPHQL.freeze
        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) {
            pullRequest(number: $number) { headRefOid mergedAt isCrossRepository
              commits(last: 1) { nodes { commit { #{ThroughputLine::HEAD_CHECKS} } } } } } }
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

      # Passing times: [] records no ready time but still moves the block to this head.
      def call(required:, times: nil)
        2.times do
          rows = times || @github.check_times
          next unless (pull = timeline) && same_head?(pull)

          carried = ThroughputStats.read(body = description_body)
          return unless carried

          updated = ThroughputStats.update(body, fields(pull, required, carried, rows))
          return if updated == body
          next unless safe_to_write?(body)

          return write(updated)
        end
      end

      # Writes the merge time only into a block that already describes the merged head.
      def merged
        pull = timeline
        return unless pull['mergedAt']

        stamp = Time.iso8601(pull['mergedAt']).utc.iso8601
        2.times do
          body = description_body
          return unless ThroughputStats.read(body)&.fetch('head', nil) == pull['headRefOid']

          updated = ThroughputStats.update(body, 't3' => stamp)
          return if updated == body
          return write(updated) if description_body == body
        end
      end

      private

      # Read the body last so the unconditional PATCH follows it as closely as possible.
      def safe_to_write?(body) = same_head?(timeline) && description_body == body

      def timeline
        owner, name = @github.repository.split('/')
        found = @github.graphql(QUERY, { owner:, name:, number: @github.number }).dig('repository', 'pullRequest')
        raise Error, 'GitHub did not report the pull request for throughput.' unless found.is_a?(Hash)

        found
      end

      def fields(pull, required, carried, times)
        ready = ThroughputStats.ready_at(before_merge(times, pull['mergedAt']), required:, review_jobs: @review_jobs,
                                                                                wait: @wait)
        start = prompt_time(pull.dig('commits', 'nodes', 0, 'commit'), carried)
        { 'head' => @head, 't1' => start }.merge(readiness_fields(ready, carried, pull))
      end

      # A check rerun after the merge cannot say when the pull request became ready.
      def before_merge(rows, merged_at)
        return rows unless merged_at

        cutoff = Time.iso8601(merged_at)
        Array(rows).reject { |row| row.is_a?(Hash) && completed_after?(row['completedAt'], cutoff) }
      end

      def completed_after?(value, cutoff)
        value.is_a?(String) && Time.iso8601(value) > cutoff
      rescue ArgumentError
        false
      end

      # Times recorded for another head must not be relabelled as this head's.
      def readiness_fields(ready, carried, pull)
        return { 't2' => ready_time(ready, carried) } unless pull['isCrossRepository']

        previous = carried['t2'] if carried['head'] == @head
        ThroughputStats.fork_readiness(ready, previous)
      end

      def ready_time(ready, carried)
        return ready_stamp(ready, carried) if ready

        carried['t2'] if carried['head'] == @head
      end

      def prompt_time(commit, carried)
        prompt = ThroughputStats.prompt_stamp(commit)
        return ThroughputStats.keep_earlier(prompt, carried, 't1', @head) if prompt

        carried['t1'] if carried['head'] == @head
      end

      def ready_stamp(ready, carried)
        seen = ready == :unknown ? 'UNKNOWN' : ready.utc.iso8601
        ThroughputStats.keep_earlier(seen, carried, 't2', @head)
      end

      def same_head?(pull) = pull.is_a?(Hash) && pull['headRefOid'] == @head

      def description_body = @github.api(path).fetch('body').to_s

      # The installed renderer wrote this change, so a branch's rendering preview no longer covers the body.
      def write(body) = @github.api(path, method: 'PATCH', fields: { body: RenderingPreview.invalidate(body) })

      def path = "repos/#{@github.repository}/pulls/#{@github.number}"
    end
  end
end
