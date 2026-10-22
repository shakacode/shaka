# frozen_string_literal: true

require_relative 'post_implementation_disposition_test'

# GitHub's merge queue offers no message box, so a ready checkpoint on a queue base says to enqueue
# the PR and what the queue will write, instead of offering a message to paste.
class MergeQueueCheckpointTest < Minitest::Test
  include PostImplementationDispositionFixture

  SETTINGS = { 'squashMergeCommitTitle' => 'PR_TITLE', 'squashMergeCommitMessage' => 'PR_BODY',
               'pullRequest' => { 'mergeQueue' => { 'configuration' => { 'mergeMethod' => 'SQUASH' } } } }.freeze

  # A PR whose base has a merge queue.
  class QueueGitHub < PostImplementationPublicationFixture::GitHub
    def snapshot = super.merge('isMergeQueueEnabled' => true)

    def graphql(query, **)
      return { 'repository' => SETTINGS } if query.include?('squashMergeCommitMessage')

      super
    end
  end

  def publish_ready(message: false)
    with_result do |result, path|
      result['disposition'] = disposition('Merge')
      File.write(path, JSON.generate(result))
      github = QueueGitHub.new('a' * 40)
      status = nil
      output = capture_io { status = Shaka::PostImplementation.run(arguments(path, message), github:) }.first
      return [github.bodies.first&.first, status, JSON.parse(output)]
    end
  end

  def arguments(path, message)
    ['publish', 'example/test', '1', '--content-file', path, *(['--squash-message', message_file(path)] if message)]
  end

  def test_ready_checkpoint_on_a_queue_base_needs_no_message_and_says_to_enqueue
    body, status, = publish_ready

    assert_equal 0, status
    assert_includes body, 'Add this PR to the merge queue'
    assert_includes body, 'WIP Details'
    refute_includes body, Shaka::SquashComment::SQUASH_MARK
    refute_includes body, 'Squash commit message'
    assert body.end_with?(Shaka::PostImplementationEvidence.attestation('a' * 40, 'ready'))
  end

  def test_a_supplied_message_is_not_offered_on_a_queue_base
    body, status, result = publish_ready(message: true)

    assert_equal 0, status
    refute_includes body, 'Fix checkpoint handoff'
    assert_equal 'not_applied_merge_queue', result.fetch('squash_message')
  end
end
