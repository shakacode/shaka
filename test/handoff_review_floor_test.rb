# frozen_string_literal: true

require_relative 'handoff_helper'
require 'shaka/merge_review_floor'

# Adds the PR file list to the reads handoff makes.
class HandoffFloorGitHub < HandoffFakeGitHub
  def api(path, **)
    pull = super
    return pull unless path == 'repos/owner/repo/pulls/42'

    pull.merge('changed_files' => @pull.fetch(:files).length)
  end

  def api_list(path)
    return @pull.fetch(:files).map { |name| { 'filename' => name } } if path.include?('/pulls/42/files')

    super
  end
end

# An Ask handoff says what merge.auto_max_review_floor would have done, so a maintainer can try it first.
class HandoffReviewFloorTest < Minitest::Test
  include HandoffHarness

  def floor_handoff(max: 2, labels: ['awaiting-merge-approval'], files: %w[lib/fix.rb])
    pull = { state: 'OPEN', head: HEAD, labels:, body: description, reviews: [walkthrough(HEAD)],
             checks: [check('pass')], comments: [], files: }
    handoff = Shaka::Handoff.new(HandoffFloorGitHub.new(pull))
    handoff.review_floor = Shaka::MergeReviewFloor.new(max)
    handoff.call(head: HEAD)
  end

  def test_reports_that_auto_would_merge_code_at_the_floor
    assert_includes floor_handoff['notes'], 'Auto would merge this PR by its paths.'
  end

  def test_reports_the_path_that_would_hand_the_pr_back
    notes = floor_handoff(files: %w[lib/fix.rb skills/shaka/SKILL.md])['notes']

    expected = 'Auto would hand this PR back: skills/shaka/SKILL.md sets review floor 3'
    assert(notes.any? { |note| note.start_with?(expected) })
  end

  def test_says_nothing_outside_an_ask_handoff_or_at_the_top_floor
    [floor_handoff(labels: ['awaiting-resume']), floor_handoff(max: 5)].each do |result|
      refute(result['notes'].any? { |note| note.start_with?('Auto would') })
    end
  end
end
