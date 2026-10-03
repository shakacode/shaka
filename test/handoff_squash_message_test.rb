# frozen_string_literal: true

require_relative 'handoff_helper'
require 'shaka/github/squash_comment'
require 'shaka/publication/squash_message'

# An Ask handoff stops for a GitHub merge click, so the squash commit message has to be on the PR first.
class HandoffSquashMessageTest < Minitest::Test
  include HandoffHarness

  # Renders the comment exactly as `squash-message` posts it.
  class Poster
    include Shaka::SquashComment

    def render(head)
      squash_comment_body(head, Shaka::SquashMessage.new({ 'title' => 'Fix', 'body' => 'Why.' }, number: 42))
    end
  end

  def squash_comment(head, id: 1, author: 'shaka-agent')
    { 'id' => id, 'body' => Poster.new.render(head), 'user' => { 'login' => author } }
  end

  def awaiting_merge(**pull) = handoff(labels: ['awaiting-merge-approval'], **pull)

  def owed?(result, text) = result.fetch('owed').any? { |item| item.include?(text) }

  def test_merge_approval_without_a_squash_message_is_owed
    result = awaiting_merge

    assert owed?(result, "squash commit message for #{HEAD}")
    assert_includes result['status'], 'no squash message'
  end

  def test_a_squash_message_for_the_live_head_settles_it
    result = awaiting_merge(comments: [squash_comment(HEAD)])

    assert_empty result['owed']
    assert_includes result['status'], "squash message #{HEAD[0, 7]}"
  end

  def test_a_squash_message_for_an_older_head_is_owed
    assert owed?(awaiting_merge(comments: [squash_comment(OLD)]), "post one for #{HEAD}")
  end

  # A fork author can mint a commit sharing the seven characters the comment displays.
  def test_a_squash_message_for_a_head_sharing_only_its_prefix_is_owed
    twin = HEAD[0, 7] + ('b' * 33)

    assert owed?(awaiting_merge(comments: [squash_comment(twin)]), "post one for #{HEAD}")
  end

  def test_the_latest_squash_message_wins
    comments = [squash_comment(HEAD, id: 1), squash_comment(OLD, id: 2)]

    assert owed?(awaiting_merge(comments:), "post one for #{HEAD}")
  end

  def test_a_copied_squash_message_from_another_account_does_not_count
    result = awaiting_merge(comments: [squash_comment(HEAD, author: 'outsider')])

    assert owed?(result, "squash commit message for #{HEAD}")
  end

  def test_a_pr_not_awaiting_merge_reads_no_comments
    assert_empty handoff(comments: nil)['owed']
  end

  def test_final_handoff_owes_both_checkpoint_and_message_until_they_exist
    result = awaiting_merge(post_implementation: {})
    assert owed?(result, 'Post-implementation review')
    assert owed?(result, 'squash commit message')
    assert_equal Shaka::Handoff::OWED_EXIT, Shaka::Handoff.exit_status(result)

    checkpoint = { 'user' => { 'login' => 'shaka-agent' },
                   'body' => "<!-- shaka:reply:post-implementation-aaaaaaa-abc12345 -->\nReport\n\n" \
                             "#{Shaka::PostImplementationEvidence.attestation(HEAD, 'ready')}" }
    result = awaiting_merge(post_implementation: {}, comments: [checkpoint, squash_comment(HEAD)])
    assert_empty result['owed']
  end

  def test_in_progress_handoff_does_not_require_an_early_checkpoint
    assert_empty handoff(post_implementation: {}, comments: nil)['owed']
  end
end
