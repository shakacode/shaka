# frozen_string_literal: true

require_relative 'error'

module Shaka
  # What GitHub's merge queue writes for a PR's commit. The queue offers no message box: it
  # applies the repository's defaults, so the person enqueues the PR instead of pasting text.
  class MergeQueueCommit
    QUERY = <<~GRAPHQL
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          squashMergeCommitTitle squashMergeCommitMessage
          pullRequest(number: $number) { mergeQueue { configuration { mergeMethod } } }
        }
      }
    GRAPHQL
    TITLES = { 'PR_TITLE' => 'the PR title',
               'COMMIT_OR_PR_TITLE' => 'the commit title for a one-commit PR, otherwise the PR title' }.freeze
    BODIES = { 'PR_BODY' => 'the whole PR description', 'COMMIT_MESSAGES' => 'the branch commit messages',
               'BLANK' => 'an empty body' }.freeze
    SETTING = '**Settings → General → Pull Requests → Allow squash merging** to **Default to pull request title** ' \
              '(`squash_merge_commit_message`)'

    # nil when the PR's base has no merge queue, so the caller keeps the prepared message.
    def self.for(github, pull) = (new(read(github)) if pull['isMergeQueueEnabled'] == true)

    # A token that cannot read repository settings still gets the instruction to enqueue.
    def self.read(github)
      owner, name = github.repository.split('/')
      github.graphql(QUERY, owner:, name:, number: github.number, feature: 'merge_queue')['repository'] || {}
    rescue Error
      {}
    end

    def initialize(repository)
      @method = repository.dig('pullRequest', 'mergeQueue', 'configuration', 'mergeMethod')
      @title = TITLES[repository['squashMergeCommitTitle']]
      @body = BODIES[repository['squashMergeCommitMessage']]
      @description = repository['squashMergeCommitMessage'] == 'PR_BODY'
    end

    def checkpoint_section
      lead = '**Merge queue:** Add this PR to the merge queue; it takes no commit message to paste.'
      ["#{lead} #{outcome}", *(warning && "**Warning:** #{warning}")].join("\n\n")
    end

    def note
      ['Merge queue: tell the person to add the PR to the merge queue; it takes no commit message to paste.',
       outcome, warning].compact.join(' ').delete('*').delete('`')
    end

    private

    def squash? = [nil, 'SQUASH'].include?(@method)

    def outcome
      return "It uses the #{@method.downcase} merge method and the repository's settings for it." unless squash?
      unless @title || @body
        return "This account could not read the queue's commit defaults; check **Settings → General → Pull Requests**."
      end

      lead = @method ? 'It squashes with' : 'If the queue squashes, it uses'
      "#{lead} #{@title || "the repository's default title"} as the title and " \
        "#{@body || "the repository's default body"} as the body."
    end

    def warning
      return unless squash? && @description

      "That puts this description, including Shaka's sections and WIP Details, into git history. " \
        "To keep it out, set #{SETTING}."
    end
  end
end
