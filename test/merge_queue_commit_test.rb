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

  def settings(title: 'PR_TITLE', body: 'PR_BODY', method: 'SQUASH')
    { 'squashMergeCommitTitle' => title, 'squashMergeCommitMessage' => body,
      'pullRequest' => { 'mergeQueue' => { 'configuration' => { 'mergeMethod' => method } } } }
  end

  def commit(settings = self.settings, queue: true)
    Shaka::MergeQueueCommit.for(GitHub.new(settings), { 'isMergeQueueEnabled' => queue })
  end

  def test_a_base_without_a_merge_queue_keeps_the_prepared_message
    [false, nil].each { |queue| assert_nil commit(queue:) }
  end

  def test_a_description_default_warns_that_the_managed_description_enters_history
    text = commit.checkpoint_section

    assert_includes text, 'Add this PR to the merge queue'
    assert_includes text, 'the PR title as the title and the whole PR description as the body'
    assert_includes text, 'WIP Details'
    assert_includes text, '**Default to pull request title**'
    assert_includes text, '`squash_merge_commit_message`'
  end

  def test_other_squash_defaults_name_what_the_queue_writes_without_a_warning
    { 'BLANK' => 'an empty body', 'COMMIT_MESSAGES' => 'the branch commit messages' }.each do |body, words|
      text = commit(settings(title: 'COMMIT_OR_PR_TITLE', body:)).checkpoint_section

      assert_includes text, "the commit title for a one-commit PR, otherwise the PR title as the title and #{words}"
      refute_includes text, 'WIP Details'
    end
  end

  def test_a_queue_that_does_not_squash_names_its_method_without_squash_defaults
    text = commit(settings(method: 'MERGE')).checkpoint_section

    assert_includes text, 'merge method'
    refute_includes text, 'PR description'
  end

  def test_unreadable_settings_say_so_instead_of_failing_the_publication
    text = commit(:unreadable).checkpoint_section

    assert_includes text, 'Add this PR to the merge queue'
    assert_includes text, 'could not read'
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
