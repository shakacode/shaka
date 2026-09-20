# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Submits an already-verified pull request through its native GitHub path.
  class MergeSubmission
    MERGE_MUTATION = <<~GRAPHQL
      mutation($id: ID!, $head: GitObjectID!) {
        mergePullRequest(input: {pullRequestId: $id, expectedHeadOid: $head, mergeMethod: SQUASH}) {
          pullRequest { state headRefOid merged mergeCommit { oid } }
        }
      }
    GRAPHQL

    ENQUEUE_MUTATION = <<~GRAPHQL
      mutation($id: ID!, $head: GitObjectID!) {
        enqueuePullRequest(input: {pullRequestId: $id, expectedHeadOid: $head}) {
          mergeQueueEntry {
            id position state estimatedTimeToMerge
            headCommit { oid }
            baseCommit { oid }
          }
        }
      }
    GRAPHQL

    def initialize(github)
      @github = github
    end

    def call(pull, head)
      return queued_result(pull, head) if pull['isInMergeQueue']
      return enqueue(pull, head) if pull['isMergeQueueEnabled']

      merge(pull.fetch('id'), head)
    rescue Error => e
      raise Error, "#{e.message}; inspect live PR state before retrying a merge"
    end

    def reconcile_queued(previous, current, head)
      entry = queued_result(previous, head).fetch('mergeQueueEntry')
      base = previous.fetch('baseRefName')
      return merged_queue_result(current, head, base, entry) if current['state'] == 'MERGED'
      return queued_result(current, head) if confirmed_queue?(current, head, base)

      if same_target?(current, head, base) && current['state'] == 'OPEN' && current['isInMergeQueue'] == false
        raise Error, 'PR left the merge queue while gates were read; retry only after a meaningful change'
      end

      raise Error, 'GitHub did not confirm the expected queued head and base'
    rescue Error => e
      raise Error, "#{e.message}; inspect live PR state before retrying a merge"
    end

    private

    def merge(id, head)
      result = @github.graphql(MERGE_MUTATION, { 'id' => id, 'head' => head })
      payload = result['mergePullRequest']
      pr = payload['pullRequest'] if payload.is_a?(Hash)
      unless pr.is_a?(Hash) && pr['merged'] == true && pr['state'] == 'MERGED' && pr['headRefOid'] == head
        raise Error, 'GitHub did not confirm merging the expected head'
      end

      pr
    end

    def enqueue(pull, head)
      result = @github.graphql(ENQUEUE_MUTATION, { 'id' => pull.fetch('id'), 'head' => head }, feature: 'merge_queue')
      payload = result['enqueuePullRequest']
      entry = payload['mergeQueueEntry'] if payload.is_a?(Hash)
      raise Error, 'GitHub did not confirm enqueueing the expected head' unless valid_entry?(entry, head)

      confirm_queue(head, pull.fetch('baseRefName'), entry)
    end

    def confirm_queue(head, base, entry)
      current = @github.snapshot
      return merged_queue_result(current, head, base, entry) if current['state'] == 'MERGED'
      return queued_result(current, head) if confirmed_queue?(current, head, base)

      raise Error, 'GitHub did not confirm queueing the expected head and base'
    end

    def same_target?(pull, head, base)
      pull['headRefOid'] == head && pull['baseRefName'] == base
    end

    def confirmed_queue?(pull, head, base)
      same_target?(pull, head, base) && pull['state'] == 'OPEN' && pull['isMergeQueueEnabled'] == true &&
        pull['isInMergeQueue'] == true
    end

    def merged_queue_result(pull, head, base, entry)
      commit = pull.dig('mergeCommit', 'oid')
      unless same_target?(pull, head, base) && pull['merged'] == true && commit.is_a?(String) &&
             commit.match?(/\A[0-9a-f]{40}\z/i)
        raise Error, 'GitHub did not confirm the expected queued merge'
      end

      queued_result({ 'mergeQueueEntry' => entry }, head)
        .merge('state' => 'MERGED', 'mergeCommit' => { 'oid' => commit })
    end

    def queued_result(pull, head)
      entry = pull['mergeQueueEntry']
      raise Error, 'GitHub reports queue membership without the expected head entry' unless valid_entry?(entry, head)

      { 'submission' => 'merge_queue', 'headRefOid' => head, 'mergeQueueEntry' => entry }
    end

    def valid_entry?(entry, head)
      return false unless entry.is_a?(Hash) && entry['id'].is_a?(String) && !entry['id'].empty?

      entry_head = entry.dig('headCommit', 'oid')
      entry_head.nil? || entry_head == head
    end
  end
end
