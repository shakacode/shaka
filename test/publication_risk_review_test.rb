# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/visible_prose'

# A reader saw Recommendation: Merge with no hint of how carefully to review: the checkpoint's risk level lived only
# in its own comment, and the code to read first sat apart from the reasons for that level.
class PublicationRiskReviewTest < Minitest::Test
  HEAD = 'a' * 40
  CHECKPOINT = 'https://github.com/owner/repo/pull/1#issuecomment-9'
  BLOB = "https://github.com/owner/repo/blob/#{HEAD}".freeze
  FOCUS = { 'path' => 'lib/merge.rb', 'reason' => 'compares the queue base before submitting.' }.freeze
  HIGH = { 'rating' => 'high', 'level' => 'high', 'areas_hit' => [], 'medium_areas_hit' => [],
           'paths_read' => true, 'max_risk' => 'low', 'reasons' => ['Changes who may merge.'],
           'url' => CHECKPOINT }.freeze

  def render(risk: nil, checkpoint: true, focus: [FOCUS], **changes)
    content = { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
                'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'deployment' => 'none',
                'steps_besides_merging' => 'none', 'intent' => INTENT.merge('review_focus' => focus),
                'verification' => VERIFICATION, 'provenance' => PUBLIC_PROVENANCE,
                'usage' => PublicationRegressionTest::USAGE_OBJECT, 'details' => [] }.merge(changes)
    content['checkpoint'] = { 'head' => HEAD, 'recommendation' => 'Merge' } if checkpoint
    pull = { 'head' => { 'sha' => HEAD }, 'shaka_risk' => risk }
    Shaka::Publication.description(content, nil, pull)
  end

  def section(rendered) = rendered[/## Risk and review\n\n.*?(?=\n\n## )/m]

  def test_the_level_leads_and_the_section_sits_between_intent_and_verification
    rendered = render(risk: HIGH)

    assert_includes rendered, '**Recommendation: Merge** · 🔴 **Risk: High** · [Code Walkthrough]('
    intent, risk, verification = ['## Intent', '## Risk and review', '## Verification'].map do |heading|
      rendered.index(heading)
    end
    assert_operator intent, :<, risk
    assert_operator risk, :<, verification
  end

  def test_a_plain_rating_says_what_it_asks_then_the_flagged_code_and_the_reviewers_reasons
    expected = "## Risk and review\n\n🔴 **High risk** is meant for a person to merge after a careful review that " \
               'starts with the verification: does the evidence prove the change works, before the code?' \
               "\n\n**Flagged by the implementer:**\n- `lib/merge.rb`, compares the queue base before submitting." \
               "\n\n**Why high**, from the [checkpoint](#{CHECKPOINT}):\n\n> - Changes who may merge."
    assert_equal expected, section(render(risk: HIGH))
  end

  def test_the_flagged_code_leaves_intent
    rendered = render(risk: HIGH)
    intent = rendered[/## Intent\n.*?(?=\n\n## )/m]

    refute_includes intent, 'lib/merge.rb'
    refute_includes rendered, 'Closer reading'
  end

  def test_an_area_that_raised_the_level_is_named_and_the_reasons_read_as_the_reviewers_rating
    raised = HIGH.merge('rating' => 'low', 'areas_hit' => [{ 'area' => 'merge_and_trust', 'path' => 'lib/seam.rb' }])
    text = section(render(risk: raised))

    assert_includes text, "**High**, raised from the reviewer's low by `merge_and_trust` (`lib/seam.rb`). " \
                          'High risk is meant for a person'
    assert_includes text, "**The [checkpoint](#{CHECKPOINT}) reviewer rated it low:**\n\n> - Changes who may merge."
    refute_includes text, 'Why high'
  end

  def test_a_low_rating_folds_its_reasons
    low = HIGH.merge('rating' => 'low', 'level' => 'low', 'reasons' => ['Only tests change.'])
    rendered = render(risk: low, focus: [])

    assert_includes rendered, '**Recommendation: Merge** · 🟢 **Risk: Low** · '
    assert_equal "## Risk and review\n\n🟢 **Low risk** is meant for auto-merge, with a later audit.\n\n" \
                 "<details>\n<summary>Why low, from the checkpoint</summary>\n\n- Only tests change.\n\n</details>",
                 section(rendered)
  end

  def test_a_level_the_setting_lets_an_agent_merge_says_so
    medium = HIGH.merge('rating' => 'medium', 'level' => 'medium', 'max_risk' => 'medium')

    assert_includes section(render(risk: medium)),
                    '**Medium risk** is at or below `merge.auto_merge_max_risk: medium`, so an agent may merge it'
  end

  def test_an_unknown_rating_counts_as_high_and_says_why
    unknown = HIGH.merge('rating' => 'unknown')
    text = section(render(risk: unknown))

    assert_includes text, '**High**; the reviewer could not judge it, so it counts as high. High risk is meant'
    assert_includes text, "**The [checkpoint](#{CHECKPOINT}) reviewer could not rate it:**"
  end

  def test_unread_changed_files_are_said_apart_from_the_reviewers_reasons
    text = section(render(risk: HIGH.merge('paths_read' => false)))

    assert_includes text, "#{Shaka::PostImplementationRisk::UNREAD_FILES}\n\n**Why high**"
  end

  def test_before_the_checkpoint_rates_the_head_the_flagged_code_still_shows
    rendered = render(risk: nil)

    assert_includes rendered, '**Recommendation: Merge** · ⚪ **Risk: not rated yet** · '
    assert_equal "## Risk and review\n\n⚪ **Not rated yet.** No published checkpoint rates this commit.\n\n" \
                 "**Flagged by the implementer:**\n- `lib/merge.rb`, compares the queue base before submitting.",
                 section(rendered)
  end

  def test_without_a_checkpoint_there_is_no_level_and_flagged_code_says_nothing_rated_it
    rendered = render(checkpoint: false)

    refute_includes rendered, '**Risk:'
    assert_includes section(rendered), '**Not rated.** No checkpoint rated this commit.'
    refute_includes render(checkpoint: false, focus: []), '## Risk and review'
  end

  def test_an_unrated_head_with_nothing_flagged_keeps_only_the_lead
    rendered = render(risk: nil, focus: [])

    assert_includes rendered, '**Risk: not rated yet**'
    refute_includes rendered, '## Risk and review'
  end

  def test_withheld_settings_show_no_level
    rendered = render(risk: { 'withheld' => 'trusted settings unread' })

    assert_includes rendered, '**Recommendation: Merge** · ⚪ **Risk: not shown** · '
    assert_includes section(rendered), "**Not shown.** Shaka could not read this repository's trusted settings"
  end

  def test_open_decisions_keep_the_lead_to_the_links
    refute_includes render(risk: HIGH, 'decisions' => ['Keep the label?']), '**Risk: High**'
  end
end

# A repository's own risk record, such as one its PR evidence guide asks for, folds into the same section.
class PublicationRiskRecordTest < Minitest::Test
  HIGH = PublicationRiskReviewTest::HIGH

  def render(...) = PublicationRiskReviewTest.new('render').render(...)
  def section(rendered) = PublicationRiskReviewTest.new('section').section(rendered)

  def test_a_repository_risk_record_folds_at_the_end_of_the_section
    record = { 'summary' => 'R3 Persistent <class> · Ask', 'body' => "```text\nRecovery: revert\n```" }
    text = section(render(risk: HIGH, 'risk_record' => record))

    assert text.end_with?("<details>\n<summary>R3 Persistent &lt;class&gt; · Ask</summary>\n\n" \
                          "```text\nRecovery: revert\n```\n\n</details>")
  end

  def test_a_risk_record_alone_still_opens_the_section
    record = { 'summary' => 'R1 Limited', 'body' => 'Recovery: revert.' }

    assert_includes section(render(checkpoint: false, focus: [], 'risk_record' => record)), '**Not rated.**'
  end

  def test_a_malformed_risk_record_is_refused
    error = assert_raises(Shaka::Error) { render('risk_record' => { 'summary' => 'R1', 'body' => 'x', 'level' => 1 }) }
    assert_includes error.message, 'unknown fields: level'
    assert_raises(Shaka::Error) { render('risk_record' => 'R1 Limited') }
    assert_raises(Shaka::Error) { render('risk_record' => { 'summary' => "R1\nR2", 'body' => 'x' }) }
  end

  def test_a_risk_record_body_cannot_open_or_close_its_fold
    record = { 'summary' => 'R1', 'body' => "Recovery: revert.\n</details>\nOutside." }
    error = assert_raises(Shaka::Error) { render('risk_record' => record) }

    assert_includes error.message, 'details or summary tags'
  end

  def test_a_risk_record_cannot_carry_a_shaka_marker
    record = { 'summary' => 'R1', 'body' => '<!-- shaka:begin -->' }

    assert_raises(Shaka::Error) { render('risk_record' => record) }
  end
end

# The checkpoint reviewer's reasons are another author's words, so they are quoted and linked only to a PR comment.
class PublicationRiskReasonsTest < Minitest::Test
  HIGH = PublicationRiskReviewTest::HIGH

  def render(...) = PublicationRiskReviewTest.new('render').render(...)
  def section(rendered) = PublicationRiskReviewTest.new('section').section(rendered)

  # The description's author cannot shorten the reviewer's reasons, so they stay out of the prose limits.
  def test_quoted_reasons_do_not_count_toward_the_prose_limits
    html = '<p><strong>Why high</strong>, from the checkpoint:</p><blockquote><ul><li>Changes who may merge.</li>' \
           '</ul></blockquote>'
    prose = Shaka::VisibleProse.new(html).paragraphs.flatten.join(' ')

    assert_includes section(render(risk: HIGH)), "\n\n> - Changes who may merge."
    refute_includes prose, 'Changes who may merge.'
  end

  def test_a_link_that_is_not_a_pr_comment_is_left_out
    text = section(render(risk: HIGH.merge('url' => 'https://example.com/x')))

    assert_includes text, '**Why high**, from the checkpoint:'
    refute_includes text, 'example.com'
  end
end

# A colored mark lets a reader see the level at a glance; the word stays beside it for anyone who cannot tell the
# colors apart.
class PublicationRiskMarkTest < Minitest::Test
  HIGH = PublicationRiskReviewTest::HIGH

  def render(...) = PublicationRiskReviewTest.new('render').render(...)

  def test_each_level_carries_its_mark_beside_the_word
    { 'low' => '🟢', 'medium' => '🟡', 'high' => '🔴' }.each do |level, mark|
      rendered = render(risk: HIGH.merge('rating' => level, 'level' => level))

      assert_includes rendered, "· #{mark} **Risk: #{level.capitalize}** ·"
      assert_includes rendered, "## Risk and review\n\n#{mark} **#{level.capitalize}"
    end
  end

  def test_unrated_states_share_the_blank_mark
    assert_includes render(risk: nil), '· ⚪ **Risk: not rated yet** ·'
    assert_includes render(risk: { 'withheld' => 'trusted settings unread' }), '· ⚪ **Risk: not shown** ·'
    assert_includes render(checkpoint: false), "## Risk and review\n\n⚪ **Not rated.**"
  end
end
