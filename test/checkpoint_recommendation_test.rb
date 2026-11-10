# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/checkpoint_recommendation'
require 'shaka/post_implementation/evidence'

class CheckpointRecommendationTest < Minitest::Test
  HEAD = 'a' * 40
  Client = Struct.new(:issue_comments, :viewer_login)

  def checkpoint(recommendation, adequacy: nil)
    marker = "#{Shaka::PostImplementationEvidence.adequacy(adequacy)}\n" if adequacy
    body = "<!-- shaka:reply:post-implementation-aaaaaaa-abc12345 -->\nReport\n\n#{marker}" \
           "#{Shaka::PostImplementationEvidence.disposition(recommendation)}\n" \
           "#{Shaka::PostImplementationEvidence.attestation(HEAD, recommendation == 'Merge' ? 'ready' : 'blocked')}"
    { 'id' => 1, 'created_at' => '2026-10-01T00:00:00Z', 'user' => { 'login' => 'agent' }, 'body' => body }
  end

  def resolve(content, comments)
    Shaka::CheckpointRecommendation.resolve(content, Client.new(comments, 'agent'))
  end

  def test_the_heading_comes_from_the_published_checkpoint
    resolved = resolve({ 'checkpoint' => { 'head' => HEAD, 'next_action' => 'Merge it.' } }, [checkpoint('Merge')])
    assert_equal 'Merge', resolved.dig('checkpoint', 'recommendation')
  end

  def test_no_published_disposition_leaves_no_recommendation
    resolved = resolve({ 'checkpoint' => { 'head' => HEAD, 'next_action' => 'Run the checkpoint.' } }, [])
    refute resolved['checkpoint'].key?('recommendation')
  end

  def test_an_agent_supplied_recommendation_is_refused
    content = { 'checkpoint' => { 'head' => HEAD, 'next_action' => 'Merge it.', 'recommendation' => 'Merge' } }
    error = assert_raises(Shaka::Error) { resolve(content, [checkpoint('Revise before merge')]) }
    assert_includes error.message, 'published checkpoint'
  end

  def test_the_verification_verdict_comes_from_the_published_checkpoint
    comments = [checkpoint('Merge', adequacy: 'adequate with accepted gaps')]
    resolved = resolve({ 'checkpoint' => { 'head' => HEAD } }, comments)
    assert_equal 'adequate with accepted gaps', resolved.dig('checkpoint', 'verification_adequacy')
  end

  def test_an_agent_supplied_verification_verdict_is_refused
    content = { 'checkpoint' => { 'head' => HEAD, 'verification_adequacy' => 'adequate' } }
    error = assert_raises(Shaka::Error) { resolve(content, [checkpoint('Merge', adequacy: 'inadequate')]) }
    assert_includes error.message, 'verification_adequacy comes from the published checkpoint'
  end

  # The waiting warning carries a hidden marker; a legacy one is recognized by its old heading alone.
  def banner(wording, head: HEAD)
    region = Shaka::MergeWarningRegion
    marker = "#{region::AWAITING_MARKER}\n" if wording == region::AWAITING
    "#{region::OPEN}\n#{marker}> **#{wording.first}**\n>\n> Reason.\n>\n" \
      '> [Blocking report](https://github.com/example/test/pull/1#issuecomment-1) · ' \
      "Head [`#{head[0, 7]}`](https://github.com/example/test/commit/#{head}). Passing checks.\n" \
      "#{region::CLOSE}\n\nFeature summary"
  end

  def require_decisions(content, body, merged: false)
    pull = { 'body' => body, 'head' => { 'sha' => HEAD }, 'merged' => merged }
    Shaka::CheckpointRecommendation.require_decisions!(content, pull, 'example/test')
  end

  def test_a_banner_waiting_on_the_maintainer_needs_the_question_in_decisions
    waiting = banner(Shaka::MergeWarningRegion::AWAITING)
    [{}, { 'decisions' => [] }, { 'checkpoint' => { 'head' => HEAD } }].each do |undecided|
      error = assert_raises(Shaka::Error) { require_decisions(undecided, waiting) }
      assert_includes error.message, 'decisions'
    end

    assert_nil require_decisions({ 'decisions' => ['Accept the risk and merge?'] }, waiting)
  end

  def test_merging_the_waiting_head_answers_its_decision
    waiting = banner(Shaka::MergeWarningRegion::AWAITING)
    [{}, { 'decisions' => [] }].each { |answered| assert_nil require_decisions(answered, waiting, merged: true) }
  end

  def answered_by_merge(body, merged: true)
    pull = { 'merged' => merged, 'head' => { 'sha' => HEAD } }
    Shaka::MergeWarningRegion.answered_by_merge(body, 'example/test', pull)
  end

  def test_a_merge_removes_only_the_warning_that_waited_on_the_merged_head
    waiting = banner(Shaka::MergeWarningRegion::AWAITING)
    assert_equal 'Feature summary', answered_by_merge(waiting)
    assert_equal waiting, answered_by_merge(waiting, merged: false)

    kept = [banner(Shaka::MergeWarningRegion::BLOCKED), banner(Shaka::MergeWarningRegion::AWAITING, head: 'b' * 40)]
    kept.each { |body| assert_equal body, answered_by_merge(body) }
  end

  def test_other_banners_and_older_heads_need_no_decisions
    [banner(Shaka::MergeWarningRegion::BLOCKED), banner(Shaka::MergeWarningRegion::AWAITING, head: 'b' * 40),
     'Feature summary'].each { |body| assert_nil require_decisions({}, body) }
  end

  def refuse_under_merge(content, comments, head: HEAD)
    pull = { 'head' => { 'sha' => head } }
    Shaka::CheckpointRecommendation.refuse_decisions_under_merge!(content, pull, Client.new(comments, 'agent'))
  end

  def test_an_open_decision_is_refused_while_this_heads_checkpoint_recommends_merge
    error = assert_raises(Shaka::Error) { refuse_under_merge({ 'decisions' => ['Accept?'] }, [checkpoint('Merge')]) }
    assert_includes error.message, Shaka::PostImplementationReport::AWAITING_DECISION
    assert_includes error.message, 'attention --state merge'
  end

  def test_decisions_need_no_new_checkpoint_when_none_recommends_merging_this_head
    open = { 'decisions' => ['Accept?'] }
    assert_nil refuse_under_merge(open, [])
    assert_nil refuse_under_merge(open, [checkpoint(Shaka::PostImplementationReport::AWAITING_DECISION)])
    assert_nil refuse_under_merge(open, [checkpoint('Merge')], head: 'b' * 40)
  end

  def test_answering_a_decision_after_the_merge_checkpoint_is_allowed
    [{}, { 'decisions' => [] }].each { |content| assert_nil refuse_under_merge(content, [checkpoint('Merge')]) }
  end

  def test_content_without_a_checkpoint_is_unchanged
    content = { 'summary' => 'Done.' }
    assert_same content, resolve(content, [])
  end
end

# Open PRs keep warnings published before the hidden marker existed, and the new heading alone proves nothing.
class MergeWarningRecognitionTest < Minitest::Test
  HEAD = 'a' * 40
  REGION = Shaka::MergeWarningRegion

  def banner(first_lines)
    "#{REGION::OPEN}\n#{first_lines}\n>\n> Reason.\n>\n" \
      '> [Blocking report](https://github.com/example/test/pull/1#issuecomment-1) · ' \
      "Head [`#{HEAD[0, 7]}`](https://github.com/example/test/commit/#{HEAD}). Passing checks.\n" \
      "#{REGION::CLOSE}\n\nFeature summary"
  end

  def waits?(body) = REGION.awaiting?(body, 'example/test', HEAD)

  def test_a_waiting_warning_published_before_the_marker_still_waits_and_clears_on_merge
    legacy = banner("> **#{REGION::LEGACY_AWAITING}**")
    pull = { 'merged' => true, 'head' => { 'sha' => HEAD } }

    assert waits?(legacy)
    assert REGION.settled_by_ready?(legacy, 'example/test', HEAD)
    assert_equal 'Feature summary', REGION.answered_by_merge(legacy, 'example/test', pull)
  end

  def test_only_the_marker_makes_the_new_heading_wait
    assert waits?(banner("#{REGION::AWAITING_MARKER}\n> **#{REGION::AWAITING.first}**"))
    refute waits?(banner("> **#{REGION::AWAITING.first}**"))
  end
end
