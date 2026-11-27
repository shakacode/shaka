# frozen_string_literal: true

require_relative 'merge_review_evidence_test'
require 'shaka/earlier_review'

# A description without results says which published review merge would accept for the head.
class EarlierReviewTest < Minitest::Test
  include MergeReviewEvidenceFixtures

  PULL = { 'head' => { 'sha' => MergeReviewEvidenceFixtures::HEAD }, 'base' => { 'ref' => 'main' } }.freeze
  URL = 'https://example.test/c/1'

  def sentence(pull = PULL, client: @client) = Shaka::EarlierReview.sentence(client, pull)

  def test_a_review_of_the_head_is_named
    @client.comments = [attestation(HEAD)]

    assert_equal "A [local review](#{URL}) of this revision is published, but its result was not passed in.", sentence
  end

  def test_an_earlier_review_with_only_markdown_since_still_applies
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => markdown_only('docs/guide.md') }

    assert_equal "The [local review](#{URL}) of `ccccccc` covers this revision, which only changes Markdown since.",
                 sentence
  end

  # MergeReviewBaseUpdateTest and MergeTreeProofTest cover the proof; this covers the wording.
  def test_a_clean_merge_of_the_base_names_the_branch_safely
    found = { 'reviewed' => EARLIER, 'comment' => 'javascript:alert(1)', 'basis' => 'unchanged_since_review' }

    assert_equal 'The local review of `ccccccc` covers this revision, which only updates it from `main`.',
                 Shaka::EarlierReview.describe(found, 'main')
    assert_includes Shaka::EarlierReview.describe(found, 'a`b'), 'updates it from the base.'
  end

  def test_nothing_is_said_when_code_changed_since_or_github_fails
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => markdown_only('lib/code.rb') }
    failing = Object.new.tap { |client| def client.viewer_login = raise(Shaka::Error, 'down') }

    assert_nil sentence
    assert_nil sentence(client: failing)
    assert_nil sentence({})
  end

  # The tree proof runs Git, so it gets the checkout only through the vetted PATH.
  def test_the_proof_gets_the_checkout_only_through_the_vetted_path
    @client.comments = [attestation(HEAD)]
    asked = nil
    vetted = lambda do |root:, select_gh:, &block|
      asked = [root, select_gh]
      block.call('/vetted/root')
    end

    assert_includes Shaka::EarlierReview.vetted_sentence(@client, PULL, root: '/checkout', safe_path: vetted),
                    'of this revision is published'
    assert_equal ['/checkout', false], asked
  end

  def test_a_refused_git_still_names_a_review_without_the_proof
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => markdown_only('docs/guide.md') }
    refused = ->(**) { raise Shaka::Error, 'git resolves inside the candidate checkout' }

    assert_includes Shaka::EarlierReview.vetted_sentence(@client, PULL, root: '/checkout', safe_path: refused),
                    'only changes Markdown since'
  end

  def test_another_accounts_attestation_is_ignored
    @client.comments = [attestation(HEAD, author: 'someone-else')]

    assert_nil sentence
  end
end
