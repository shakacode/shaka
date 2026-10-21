# frozen_string_literal: true

require_relative 'error'

module Shaka
  # What GitHub's merge queue writes for a PR's commit. The queue offers no message box: it
  # applies the repository's defaults. When those copy the PR description, `merge` puts the
  # prepared message there first; otherwise the person enqueues the PR without pasting text.
  class MergeQueueCommit
    QUERY = <<~GRAPHQL
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          squashMergeCommitTitle squashMergeCommitMessage mergeCommitTitle mergeCommitMessage
          pullRequest(number: $number) { mergeQueue { configuration { mergeMethod } } }
        }
      }
    GRAPHQL
    # The defaults each queue method reads, and the GitHub setting that chooses them. A rebase writes no message.
    STYLES = {
      'SQUASH' => { verb: 'squashes with', fields: %w[squashMergeCommitTitle squashMergeCommitMessage],
                    setting: 'Allow squash merging', api: 'squash_merge_commit_message' },
      'MERGE' => { verb: 'creates a merge commit with', fields: %w[mergeCommitTitle mergeCommitMessage],
                   setting: 'Allow merge commits', api: 'merge_commit_message' }
    }.freeze
    TITLES = { 'PR_TITLE' => 'the PR title', 'MERGE_MESSAGE' => "GitHub's default merge message",
               'COMMIT_OR_PR_TITLE' => 'the commit title for a one-commit PR, otherwise the PR title' }.freeze
    BODIES = { 'PR_BODY' => 'the PR description', 'COMMIT_MESSAGES' => 'the branch commit messages',
               'PR_TITLE' => 'the PR title', 'BLANK' => 'an empty body' }.freeze

    # nil when the PR's base has no merge queue, so the caller keeps the prepared message.
    def self.for(github, pull) = (new(read(github)) if pull['isMergeQueueEnabled'] == true)

    # GitHub builds the queue commit as the PR enters the queue, so a queue that copies the PR
    # description gets the prepared message there first. Answers what the merge result reports.
    def self.describe(github, message)
      return {} unless new(read(github)).copies_description?
      raise Error, 'This merge queue copies the PR description into its commit; pass --squash-message.' unless message

      { 'squash_message' => 'applied_through_description', 'parked_description' => github.queue_description(message) }
    end

    # A token that cannot read repository settings still gets the instruction to enqueue.
    def self.read(github)
      owner, name = github.repository.split('/')
      github.graphql(QUERY, owner:, name:, number: github.number, feature: 'merge_queue')['repository'] || {}
    rescue Error
      {}
    end

    def initialize(repository)
      @method = repository.dig('pullRequest', 'mergeQueue', 'configuration', 'mergeMethod')
      @style = STYLES[@method || 'SQUASH']
      @title, @body = repository.values_at(*@style[:fields]) if @style
    end

    # Unread defaults count as copying: parking a description costs less than leaking one into history.
    def copies_description? = @method != 'REBASE' && (@body == 'PR_BODY' || !BODIES.key?(@body))

    # Whether this account read the commit defaults, and the GitHub setting that chooses them.
    def defaults_read? = @method == 'REBASE' || BODIES.key?(@body)
    def setting = @style && "**Settings → General → Pull Requests → #{@style[:setting]}** (`#{@style[:api]}`)"

    def checkpoint_section
      lead = if copies_description?
               'Ask Shaka to merge this head. It puts the prepared commit message in the PR description, ' \
                 'then adds the PR to the queue.'
             else
               'Add this PR to the merge queue; it takes no commit message to paste.'
             end
      ["**Merge queue:** #{lead} #{outcome}", *(warning && "**Warning:** #{warning}")].join("\n\n")
    end

    def note
      lead = if copies_description?
               'tell the person to ask you to merge this head: `merge` puts the prepared commit message in ' \
                 'the PR description before it adds the PR to the queue.'
             else
               'tell the person to add the PR to the merge queue; it takes no commit message to paste.'
             end
      ["Merge queue: #{lead}", outcome, warning].compact.join(' ').delete('*').delete('`')
    end

    private

    def outcome
      return 'It rebases the branch commits onto the base, keeping their own messages.' if @method == 'REBASE'
      unless TITLES[@title] || BODIES[@body]
        return "This account could not read the queue's commit defaults; check **Settings → General → Pull Requests**."
      end

      lead = @method ? "It #{@style[:verb]}" : 'If the queue squashes, it uses'
      "#{lead} #{TITLES.fetch(@title, "the repository's default title")} as the title and " \
        "#{BODIES.fetch(@body, "the repository's default body")} as the body."
    end

    def warning
      return unless @body == 'PR_BODY'

      'Adding the PR to the queue yourself puts this whole description, including Shaka\'s sections and ' \
        "WIP Details, into git history. To make that click safe, set #{setting} to **Pull request title** " \
        'or **Default message**; the queue then leaves out the prepared message.'
    end
  end
end
