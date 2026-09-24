# frozen_string_literal: true

require_relative 'merge_review_evidence_test'

# Bringing a reviewed branch up to date with its base keeps the review when the PR's own changes are unchanged.
class MergeReviewBaseUpdateTest < Minitest::Test
  include MergeReviewEvidenceFixtures

  PATCH = "@@ -10,6 +10,7 @@ def call\n   keep\n+  added\n   keep"

  OLD_BASE = 'e' * 40
  NEW_BASE = 'f' * 40

  def changes(patch: PATCH, name: 'lib/merge.rb', merge_base: OLD_BASE, **fields)
    { 'status' => 'ahead', 'merge_base_commit' => { 'sha' => merge_base },
      'files' => [{ 'filename' => name, 'status' => 'modified', 'patch' => patch }.merge(fields)] }
  end

  # The head's merge base defaults to NEW_BASE, and the base update between them touched `base_files`.
  def update_from_base(reviewed_changes, head_changes, since_review: 'diverged', base_files: ['lib/merge.rb'])
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => { 'status' => since_review, 'files' => [{ 'filename' => 'lib/other.rb' }] },
                            ['main', EARLIER] => reviewed_changes, ['main', HEAD] => head_changes,
                            [OLD_BASE, NEW_BASE] => { 'status' => 'ahead',
                                                      'files' => base_files.map { |name| { 'filename' => name } } } }
  end

  def base_evidence = Shaka::MergeReviewEvidence.new(@client, required: 'meaningful_changes').call(HEAD, base: 'main')

  def test_a_clean_rebase_keeps_the_review
    update_from_base(changes, changes(merge_base: NEW_BASE))

    result = base_evidence

    assert_equal 'unchanged_since_review', result.fetch('basis')
    assert_equal EARLIER, result.fetch('reviewed')
  end

  def test_merging_the_base_into_the_branch_keeps_the_review
    update_from_base(changes, changes(merge_base: NEW_BASE), since_review: 'ahead')

    assert_equal 'unchanged_since_review', base_evidence.fetch('basis')
  end

  # The base added lines above the PR's hunk in that file, so only the hunk position moved.
  def test_positions_may_shift_in_a_file_the_base_update_changed
    update_from_base(changes, changes(patch: PATCH.sub('-10,6 +10,7', '-42,6 +42,7'), merge_base: NEW_BASE))

    assert_equal 'unchanged_since_review', base_evidence.fetch('basis')
  end

  # Moving an edit between identical blocks keeps the patch text; only its position shows the move.
  def test_a_moved_hunk_needs_a_new_review_when_the_base_did_not_change_that_file
    moved = changes(patch: PATCH.sub('-10,6 +10,7', '-42,6 +42,7'), merge_base: NEW_BASE)
    update_from_base(changes, moved, base_files: ['lib/other.rb'])

    assert_raises(Shaka::Error) { base_evidence }
  end

  def test_a_moved_hunk_needs_a_new_review_when_the_base_did_not_move
    update_from_base(changes, changes(patch: PATCH.sub('-10,6 +10,7', '-42,6 +42,7')))

    assert_raises(Shaka::Error) { base_evidence }
  end

  def test_a_changed_pr_line_needs_a_new_review
    update_from_base(changes, changes(patch: PATCH.sub('added', 'resolved differently'), merge_base: NEW_BASE))

    error = assert_raises(Shaka::Error) { base_evidence }
    assert_match(/differ from what was reviewed/, error.message)
  end

  # GitHub gives no patch for a binary file, so its blob identity decides.
  def test_a_binary_file_keeps_the_review_only_with_identical_contents
    same = changes(patch: nil, name: 'logo.png', 'sha' => 'b1')
    update_from_base(same, same.merge('merge_base_commit' => { 'sha' => NEW_BASE }))
    assert_equal 'unchanged_since_review', base_evidence.fetch('basis')

    update_from_base(same, changes(patch: nil, name: 'logo.png', 'sha' => 'b2', merge_base: NEW_BASE))
    assert_raises(Shaka::Error) { base_evidence }
  end

  def test_a_file_without_a_patch_or_blob_cannot_be_compared
    update_from_base(changes(patch: nil), changes(patch: nil, merge_base: NEW_BASE))

    assert_raises(Shaka::Error) { base_evidence }
  end

  def test_without_a_base_only_the_markdown_rule_applies
    update_from_base(changes, changes(merge_base: NEW_BASE))

    assert_raises(Shaka::Error) { evidence }
    refute_includes @client.compared, ['main', HEAD]
  end
end
