# frozen_string_literal: true

require_relative 'error'

module Shaka
  # What GitHub's merge queue writes for a PR's commit. The queue offers no message box: it
  # applies the repository's defaults, so the person enqueues the PR instead of pasting text.
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
    BODIES = { 'PR_BODY' => 'the whole PR description', 'COMMIT_MESSAGES' => 'the branch commit messages',
               'PR_TITLE' => 'the PR title', 'BLANK' => 'an empty body' }.freeze

    # nil when the PR's base has no merge queue, so the caller keeps the prepared message.
    def self.for(github, pull) = (new(read(github)) if pull['isMergeQueueEnabled'] == true)

    # A queue that copies the PR description would commit Shaka's sections and WIP Details, so
    # Shaka adds no PR to one. Unread defaults might copy it too. The maintainer chose a fixed
    # refusal over a setting (shakacode/shaka#824); a repository that wants its descriptions in
    # commits can still use GitHub's queue button.
    def self.refuse_copying!(github)
      queue = new(read(github))
      raise Error, queue.refusal if queue.copies_description?
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

    # Unread defaults count as copying: a refused merge costs less than a description in history.
    def copies_description? = @method != 'REBASE' && (@body == 'PR_BODY' || !BODIES.key?(@body))

    # Whether this account read the commit defaults, and the GitHub setting that chooses them.
    def defaults_read? = @method == 'REBASE' || BODIES.key?(@body)
    def setting = @style && "**Settings → General → Pull Requests → #{@style[:setting]}** (`#{@style[:api]}`)"

    def checkpoint_section
      lead = '**Merge queue:** Add this PR to the merge queue; it takes no commit message to paste.'
      ["#{lead} #{outcome}", *(warning && "**Warning:** #{warning}")].join("\n\n")
    end

    def note
      ['Merge queue: tell the person to add the PR to the merge queue; it takes no commit message to paste.',
       outcome, warning].compact.join(' ').delete('*').delete('`')
    end

    # `merge` adds its own advice after this sentence, so it ends without a period.
    def refusal
      unless defaults_read?
        return "Could not read this merge queue's commit defaults, which might copy the PR description " \
               'into its commit. Check Settings → General → Pull Requests, then merge again'
      end

      "This merge queue copies the PR description into its commit. Set #{setting.delete('*')} to " \
        'Default message or Pull request title, then merge again'
    end

    private

    def outcome
      return 'It rebases the branch commits onto the base, keeping their own messages.' if @method == 'REBASE'
      unless TITLES[@title] || BODIES[@body]
        return "This account could not read the queue's commit defaults, so Shaka's merge refuses it; " \
               'check **Settings → General → Pull Requests**.'
      end

      lead = @method ? "It #{@style[:verb]}" : 'If the queue squashes, it uses'
      "#{lead} #{TITLES.fetch(@title, "the repository's default title")} as the title and " \
        "#{BODIES.fetch(@body, "the repository's default body")} as the body."
    end

    def warning
      return unless @body == 'PR_BODY'

      "That puts this description, including Shaka's sections and WIP Details, into git history, and " \
        "Shaka's merge refuses this queue. Before adding the PR, set #{setting} to **Default message** or " \
        '**Pull request title**.'
    end
  end
end
