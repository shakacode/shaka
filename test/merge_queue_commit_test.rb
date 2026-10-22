# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/merge_queue_commit'

# GitHub's merge queue takes no commit message, so Shaka says what the queue will write instead.
class MergeQueueCommitTest < Minitest::Test
  # Answers the one settings read, or fails it as a token without access would.
  class GitHub
    attr_reader :repository, :number, :features

    def initialize(settings)
      @repository = 'owner/repo'
      @number = 42
      @settings = settings
      @features = []
    end

    def graphql(_query, feature: nil, **)
      @features << feature
      raise Shaka::Error, 'GraphQL failed or returned missing data.' if @settings == :unreadable

      { 'repository' => @settings }
    end
  end

  def settings(title: 'PR_TITLE', body: 'PR_BODY', method: 'SQUASH', merge: %w[MERGE_MESSAGE PR_TITLE])
    { 'squashMergeCommitTitle' => title, 'squashMergeCommitMessage' => body,
      'mergeCommitTitle' => merge.first, 'mergeCommitMessage' => merge.last,
      'pullRequest' => { 'mergeQueue' => { 'configuration' => { 'mergeMethod' => method } } } }
  end

  def commit(settings = self.settings, queue: true)
    Shaka::MergeQueueCommit.for(GitHub.new(settings), { 'isMergeQueueEnabled' => queue })
  end

  def test_a_base_without_a_merge_queue_keeps_the_prepared_message
    [false, nil].each { |queue| assert_nil commit(queue:) }
  end

  def test_a_description_default_warns_that_the_managed_description_enters_history
    queue = commit
    text = queue.checkpoint_section

    assert_predicate queue, :copies_description?
    assert_includes text, 'Add this PR to the merge queue'
    assert_includes text, 'the PR title as the title and the whole PR description as the body'
    assert_includes text, 'WIP Details'
    assert_includes text, "Shaka's merge refuses this queue"
    assert_includes text, '**Default message** or **Pull request title**'
    assert_includes text, '`squash_merge_commit_message`'
    assert_includes queue.refusal, 'Allow squash merging (`squash_merge_commit_message`) to Default message'
  end

  def test_other_squash_defaults_name_what_the_queue_writes_without_a_warning
    { 'BLANK' => 'an empty body', 'COMMIT_MESSAGES' => 'the branch commit messages' }.each do |body, words|
      queue = commit(settings(title: 'COMMIT_OR_PR_TITLE', body:))
      text = queue.checkpoint_section

      refute_predicate queue, :copies_description?
      assert_includes text, 'Add this PR to the merge queue'
      assert_includes text, "the commit title for a one-commit PR, otherwise the PR title as the title and #{words}"
      refute_includes text, 'WIP Details'
    end
  end

  def test_a_merge_commit_queue_reads_the_merge_commit_defaults
    text = commit(settings(method: 'MERGE')).checkpoint_section

    assert_includes text, "It creates a merge commit with GitHub's default merge message as the title and the PR title"
    refute_includes text, 'WIP Details'
  end

  # A merge commit can copy the description too, through its own setting.
  def test_a_merge_commit_description_default_warns_and_names_its_own_setting
    text = commit(settings(method: 'MERGE', body: 'BLANK', merge: %w[PR_TITLE PR_BODY])).checkpoint_section

    assert_includes text, 'WIP Details'
    assert_includes text, '**Settings → General → Pull Requests → Allow merge commits**'
    assert_includes text, '`merge_commit_message`'
  end

  def test_a_rebase_queue_writes_no_new_message
    queue = commit(settings(method: 'REBASE'))

    refute_predicate queue, :copies_description?
    assert_includes queue.checkpoint_section, 'rebases the branch commits'
    refute_includes queue.checkpoint_section, 'WIP Details'
  end

  # Unread defaults might copy the description, so Shaka's merge refuses rather than risk history.
  def test_unreadable_settings_say_so_and_count_as_copying_the_description
    queue = commit(:unreadable)

    assert_predicate queue, :copies_description?
    refute_predicate queue, :defaults_read?
    assert_includes queue.checkpoint_section, 'Add this PR to the merge queue'
    assert_includes queue.checkpoint_section, "could not read the queue's commit defaults, so Shaka's merge refuses it"
    assert_includes queue.refusal, 'Could not read'
  end

  def test_an_unread_method_still_warns_about_a_description_default
    text = commit(settings(method: nil)).checkpoint_section

    assert_includes text, 'If the queue squashes'
    assert_includes text, 'WIP Details'
  end

  def test_the_handoff_note_is_plain_text_for_the_agent
    note = commit.note

    assert note.start_with?('Merge queue: tell the person to add the PR to the merge queue')
    refute_includes note, '**'
    assert_includes note, 'WIP Details'
  end

  def test_the_settings_read_uses_the_merge_queue_feature
    github = GitHub.new(settings)
    Shaka::MergeQueueCommit.for(github, { 'isMergeQueueEnabled' => true })

    assert_equal ['merge_queue'], github.features
  end
end
