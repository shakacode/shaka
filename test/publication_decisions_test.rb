# frozen_string_literal: true

require_relative 'publication_test'

class PublicationDecisionsTest < Minitest::Test
  def render(**changes)
    Shaka::Publication.description(
      { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
        'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'deployment' => 'none',
        'steps_besides_merging' => 'none',
        'intent' => INTENT, 'verification' => VERIFICATION,
        'table' => PublicationRegressionTest::TABLE, 'provenance' => PUBLIC_PROVENANCE,
        'usage' => PublicationRegressionTest::USAGE_OBJECT, 'details' => [] }.merge(changes)
    )
  end

  def test_decisions_lead_the_description_before_the_links_and_sections
    rendered = render('decisions' => ['Keep the label?', 'Which base?'],
                      'sections' => [{ 'heading' => 'Outcome', 'body' => 'What landed.' }])
    marker = "<!-- shaka:decisions -->\n## Decisions to make<a id=\"decisions-to-make\"></a>\n\n" \
             "- Keep the label?\n- Which base?\n"
    decisions = rendered.index(marker)
    walkthrough = rendered.index('[Code Walkthrough](')
    outcome = rendered.index("## Outcome\n")

    refute_nil decisions
    assert_operator decisions, :<, walkthrough
    assert_operator walkthrough, :<, outcome
  end

  def test_an_empty_decisions_list_omits_the_section
    refute_includes render('decisions' => []), 'Decisions to make'
  end

  # GitHub gives comment headings no anchor, so the link targets the one the heading carries.
  def test_open_decisions_hold_the_walkthrough_and_name_the_checkpoint
    rendered = render('decisions' => ['Keep the label?'], 'walkthrough' => nil)

    assert_includes rendered, "\n\nCode Walkthrough: _After the decisions._ · " \
                              "Checkpoint: [Decisions to make](#user-content-decisions-to-make)\n\n## Summary"
    refute_includes rendered, 'Not published yet'
  end

  def test_without_decisions_the_links_still_say_not_published
    rendered = render('decisions' => [], 'walkthrough' => nil)

    assert_includes rendered, "\n\n_Not published yet._ · Checkpoint: _Not published yet._\n\n## Summary"
    refute_includes rendered, 'After the decisions'
  end

  # A walkthrough someone asked for early, or a published checkpoint, is evidence the reader can open.
  def test_open_decisions_keep_published_links
    checkpoint = 'https://github.com/shakacode/shaka/pull/137#issuecomment-42'
    rendered = render('decisions' => ['Keep the label?'], 'post_implementation' => checkpoint)

    assert_includes rendered, "[Code Walkthrough](#{PublicationRegressionTest::WALKTHROUGH}) · " \
                              "[Checkpoint](#{checkpoint})\n\n## Summary"
    refute_includes rendered, 'After the decisions'
    refute_includes rendered, '(#user-content-decisions-to-make)'
  end

  def test_a_hand_written_decisions_section_is_refused
    error = assert_raises(Shaka::Error) do
      render('sections' => [{ 'heading' => 'Decisions to make', 'body' => '- One?' }])
    end
    assert_includes error.message, 'decisions list'
  end

  def test_a_blank_decision_is_refused
    error = assert_raises(Shaka::Error) { render('decisions' => ['  ']) }
    assert_includes error.message, 'decision'
  end
end
