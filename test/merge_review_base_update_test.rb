# frozen_string_literal: true

require_relative 'merge_review_evidence_test'

# Bringing a reviewed branch up to date with its base keeps the review when the PR's own changes are unchanged.
class MergeReviewBaseUpdateTest < Minitest::Test
  include MergeReviewEvidenceFixtures

  PATCH = "@@ -10,6 +10,7 @@ def call\n   keep\n+  added\n   keep"

  def changes(patch: PATCH, name: 'lib/merge.rb', **fields)
    { 'status' => 'ahead', 'files' => [{ 'filename' => name, 'status' => 'modified', 'patch' => patch }.merge(fields)] }
  end

  def update_from_base(reviewed_changes, head_changes, since_review: 'diverged')
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => { 'status' => since_review, 'files' => [{ 'filename' => 'lib/other.rb' }] },
                            ['main', EARLIER] => reviewed_changes, ['main', HEAD] => head_changes }
  end

  def base_evidence = Shaka::MergeReviewEvidence.new(@client, required: 'meaningful_changes').call(HEAD, base: 'main')

  def test_a_clean_rebase_keeps_the_review
    update_from_base(changes, changes)

    result = base_evidence

    assert_equal 'unchanged_since_review', result.fetch('basis')
    assert_equal EARLIER, result.fetch('reviewed')
  end

  def test_merging_the_base_into_the_branch_keeps_the_review
    update_from_base(changes, changes, since_review: 'ahead')

    assert_equal 'unchanged_since_review', base_evidence.fetch('basis')
  end

  # The base may add lines above the PR's hunk; only the hunk position moves.
  def test_shifted_hunk_positions_still_match
    update_from_base(changes, changes(patch: PATCH.sub('-10,6 +10,7', '-42,6 +42,7')))

    assert_equal 'unchanged_since_review', base_evidence.fetch('basis')
  end

  def test_a_changed_pr_line_needs_a_new_review
    update_from_base(changes, changes(patch: PATCH.sub('added', 'resolved differently')))

    error = assert_raises(Shaka::Error) { base_evidence }
    assert_match(/differ from what was reviewed/, error.message)
  end

  def test_a_file_without_a_patch_cannot_be_compared
    update_from_base(changes(patch: nil, 'changes' => 12), changes(patch: nil, 'changes' => 12))

    assert_raises(Shaka::Error) { base_evidence }
  end

  def test_a_pure_rename_compares_without_a_patch
    rename = { 'status' => 'renamed', 'previous_filename' => 'lib/old.rb', 'changes' => 0 }
    update_from_base(changes(patch: nil, **rename), changes(patch: nil, **rename))

    assert_equal 'unchanged_since_review', base_evidence.fetch('basis')
  end

  def test_without_a_base_only_the_markdown_rule_applies
    update_from_base(changes, changes)

    assert_raises(Shaka::Error) { evidence }
    refute_includes @client.compared, ['main', HEAD]
  end
end
