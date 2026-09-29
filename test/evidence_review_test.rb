# frozen_string_literal: true

require_relative 'evidence_fixture'

class EvidenceReviewTest < Minitest::Test
  include EvidenceFixture

  def test_review_check_records_committed_content_and_settings
    with_checkout do |root, ref|
      result = review_check(root, ref)
      assert_equal 'reported', result.fetch('status')
      assert_equal git(root, 'rev-parse', "#{ref}^{tree}"), result.fetch('tested_tree')
      assert_equal 'observed_at_review_check', result.fetch('settings_basis')
      refute result.fetch('review_provisional')
      assert_equal 'bound', bind(root, ref, ref, result).fetch('status')
    end
  end

  def test_dirty_review_check_stays_provisional_even_if_worktree_tree_matches_head
    with_checkout do |root, ref|
      File.write(File.join(root, 'staged-only'), 'different')
      git(root, 'add', 'staged-only')
      File.delete(File.join(root, 'staged-only'))
      result = review_check(root, ref)
      assert_equal result.fetch('tested_tree'), result.fetch('candidate_tree_before')
      assert result.fetch('review_provisional')
      assert_includes bind(root, ref, ref, result).fetch('reasons'), 'review did not inspect committed candidate'
    end
  end

  def test_review_of_old_head_does_not_bind_to_new_commit_with_same_tree
    with_checkout do |root, ref|
      result = review_check(root, ref)
      git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
          'commit', '--allow-empty', '--quiet', '-m', 'same tree')
      head = git(root, 'rev-parse', 'HEAD')
      binding = bind(root, ref, head, result)
      assert_equal 'superseded', binding.fetch('status')
      assert_includes binding.fetch('reasons'), 'review attests another commit'
    end
  end
end
