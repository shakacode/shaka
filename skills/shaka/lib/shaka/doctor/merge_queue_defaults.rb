# frozen_string_literal: true

require 'json'
require_relative 'check'
require_relative '../merge_queue_commit'

module Shaka
  class Doctor
    # Whether adding a PR to the default branch's merge queue on GitHub would copy its whole
    # description, Shaka's sections and WIP Details included, into git history.
    class MergeQueueDefaults
      include Check

      NAME = 'Merge queue commits'
      QUERY = <<~GRAPHQL
        query($owner: String!, $name: String!) {
          repository(owner: $owner, name: $name) {
            squashMergeCommitTitle squashMergeCommitMessage mergeCommitTitle mergeCommitMessage
            mergeQueue { configuration { mergeMethod } }
          }
        }
      GRAPHQL

      # `run` takes an argv and returns stdout, stderr, and success, like Checks#run.
      def initialize(run)
        @run = run
      end

      def call
        out, error, ok = @run.call(['gh', 'api', 'graphql', '-H', 'GraphQL-Features: merge_queue',
                                    '-F', 'owner={owner}', '-F', 'name={repo}', '-f', "query=#{QUERY}"])
        return unread(first_line(error)) unless ok

        judge(JSON.parse(out).dig('data', 'repository'))
      rescue JSON::ParserError
        unread('gh returned a response that is not GraphQL JSON')
      end

      private

      def judge(repository)
        return unread('GitHub did not return the repository') unless repository.is_a?(Hash)
        return check(NAME, 'healthy', 'the default branch has no merge queue') unless repository['mergeQueue']

        # The queue's own method chooses which commit defaults it reads, as for a PR on that branch.
        commit = MergeQueueCommit.new(repository.merge('pullRequest' => { 'mergeQueue' => repository['mergeQueue'] }))
        return unread('this account could not read the queue\'s commit defaults') unless commit.defaults_read?
        return check(NAME, 'healthy', 'the merge queue leaves the PR description out of commits') unless
          commit.copies_description?

        check(NAME, 'degraded', 'adding a PR to the merge queue on GitHub copies its whole description, ' \
                                "including Shaka's sections and WIP Details, into git history",
              guidance: 'Ask Shaka to merge, which puts the prepared commit message in the description first, ' \
                        "or set #{commit.setting.delete('*')} to Pull request title or Default message.")
      end

      def unread(reason)
        check(NAME, 'degraded', "not checked: #{reason}",
              guidance: 'Run doctor inside the checkout you publish from, signed in with `gh auth login`.')
      end
    end
  end
end
