# frozen_string_literal: true

require_relative 'publication_test'

# A PR stayed a draft after its checkpoint recommended Merge, and the description still told the maintainer to merge.
class PublicationDraftLeadTest < Minitest::Test
  HEAD = 'a' * 40

  def render(recommendation, draft:)
    content = { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
                'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'deployment' => 'none',
                'steps_besides_merging' => 'none', 'intent' => INTENT, 'verification' => VERIFICATION,
                'provenance' => PUBLIC_PROVENANCE, 'usage' => PublicationRegressionTest::USAGE_OBJECT,
                'details' => [], 'checkpoint' => { 'head' => HEAD, 'recommendation' => recommendation } }
    Shaka::Publication.description(content, nil, { 'head' => { 'sha' => HEAD }, 'draft' => draft })
  end

  def test_a_draft_never_reads_as_a_merge_recommendation
    rendered = render('Merge', draft: true)

    refute_includes rendered, 'Recommendation: Merge'
    assert_includes rendered, '**Draft: mark it ready for review before merging** · '
  end

  def test_a_ready_pr_keeps_the_merge_recommendation
    assert_includes render('Merge', draft: false), '**Recommendation: Merge** · '
  end

  def test_a_draft_keeps_a_recommendation_against_merging
    assert_includes render('Revise before merge', draft: true), '**Recommendation: Revise before merge** · '
  end
end
