# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'claim_helpers'

class ClaimReferenceTest < Minitest::Test
  include ClaimHelpers

  PR = { 'number' => 402, 'title' => 'Feedback intake', 'url' => 'https://github.com/shakacode/shaka/pull/402',
         'headRefName' => 'justin808-codex/400-feedback', 'body' => '', 'closingIssuesReferences' => [] }.freeze

  def test_test_counts_and_provenance_digits_are_not_references
    ['2,392 tests passed', '392 tests passed', '02a392bc', 'run-392-evidence', '405.0 tokens'].each do |text|
      query = text.include?('405') ? '405' : '392'
      refute claim(query, prs: [PR.merge('body' => text)], branches: '').fetch('collision'), text
    end
  end

  def test_explicit_references_remain_collisions_even_without_a_closing_relationship
    ['Fixes #392', 'Related to #392; scope unclear', 'Issue 392', 'PR 392', 'pull request 392',
     'shakacode/shaka#392', 'https://github.com/shakacode/shaka/issues/392',
     'https://github.com/shakacode/shaka/pull/392#discussion_r1',
     'See https://github.com/shakacode/shaka/issues/392.',
     '[task](https://github.com/shakacode/shaka/issues/392)'].each do |text|
      assert claim('392', prs: [PR.merge('body' => text)], branches: '').fetch('collision'), text
    end
  end

  def test_title_references_are_collisions
    assert claim('392', prs: [PR.merge('title' => 'Follow up #392')], branches: '').fetch('collision')
  end

  def test_other_repositories_and_longer_numbers_do_not_collide
    ['other/repo#392', 'https://github.com/other/repo/issues/392', '#3920', '#392abc',
     'https://example.com/build#392', 'https://github.com/shakacode/shaka/issues/3920',
     'https://github.com/shakacode/shaka/issues/400#392'].each do |text|
      refute claim('392', prs: [PR.merge('body' => text)], branches: '').fetch('collision'), text
    end
  end

  def test_github_closing_relationships_are_collisions
    refs = [{ 'number' => 392, 'url' => 'https://github.com/shakacode/shaka/issues/392' }]
    assert claim('392', prs: [PR.merge('closingIssuesReferences' => refs)], branches: '').fetch('collision')
    refs.first['url'] = 'https://github.com/other/repo/issues/392'
    refute claim('392', prs: [PR.merge('closingIssuesReferences' => refs)], branches: '').fetch('collision')
  end

  def test_a_named_open_pr_is_its_own_collision
    assert claim('402', prs: [PR], branches: '').fetch('collision')
  end

  def test_a_pr_head_matches_without_prose_or_a_listed_remote_branch
    result = claim('392', prs: [PR.merge('headRefName' => 'alex/392-fix')], branches: '')
    assert result.fetch('collision')
    assert_equal([402], result.fetch('pull_requests').map { |pr| pr.fetch('number') })
  end

  def test_an_explicit_tracker_pr_head_matches_without_the_key
    assert claim('ENG-123', prs: [PR.merge('headRefName' => 'alex/fix-search')], branches: '',
                            tracker_branch: 'alex/fix-search').fetch('collision')
  end

  def test_tracker_references_match_case_insensitively_without_matching_longer_keys
    assert claim('ENG-123', prs: [PR.merge('body' => 'Fixes eng-123.')], branches: '').fetch('collision')
    %w[ENG-1234 MY-ENG-123 ENG-123abc].each do |text|
      refute claim('ENG-123', prs: [PR.merge('body' => text)], branches: '').fetch('collision'), text
    end
  end

  def test_collision_output_keeps_the_existing_summary_fields
    result = claim('400', prs: [PR], branches: '')
    assert_equal PR.slice('number', 'title', 'url', 'headRefName'), result.fetch('pull_requests').first
  end
end
