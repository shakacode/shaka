# frozen_string_literal: true

require_relative 'publication_test'

class PublicationTaskUnderstandingTest < Minitest::Test
  UNDERSTANDING = { 'goal' => 'Let customers export the orders matching their current filters.',
                    'done_when' => 'The CSV contains the same orders as the page.' }.freeze
  SHOWN = "- **Goal:** Let customers export the orders matching their current filters.\n" \
          '- **Done when:** The CSV contains the same orders as the page.'

  def test_the_goal_and_success_criteria_nest_under_the_task_line
    rendered = render

    assert_includes rendered, "**Task:** Codex prompt\n#{SHOWN}\n\n**Safe because:**"
    refute_includes rendered, '<summary>Task as understood</summary>'
  end

  def test_older_text_keeps_its_paragraphs_inside_one_nested_item
    understanding = "  First paragraph\nwraps here.\n \nSecond paragraph.\n\n\nThird paragraph.\n"
    rendered = render('intent' => INTENT.merge('task_understanding' => understanding))

    assert_includes rendered, "**Task:** Codex prompt\n- **As understood:** First paragraph\n  wraps here.\n\n  " \
                              "Second paragraph.\n\n  Third paragraph.\n\n**Safe because:**"
  end

  def test_the_same_understanding_can_accompany_an_issue_or_another_agent
    issue = PUBLIC_PROVENANCE.merge('task_source' => 'issue', 'task_number' => 1234)
    assert_includes render('provenance' => issue), "**Task:** GitHub #1234\n#{SHOWN}"
    claude = PublicationRegressionTest::IDENTITY.merge('agent' => 'Claude Code')
    assert_includes render('identity' => claude), "**Task:** Claude prompt\n#{SHOWN}"
  end

  def test_older_callers_can_omit_the_understanding
    rendered = render('intent' => INTENT)

    assert_includes rendered, "**Task:** Codex prompt\n\n**Safe because:**"
    refute_includes rendered, 'Goal:'
  end

  def test_supplied_understanding_requires_nonempty_text_with_real_line_breaks
    ['', ' ', 17, [], 'Outcome.\nSuccess.'].each do |value|
      error = assert_raises(Shaka::Error) { render('intent' => INTENT.merge('task_understanding' => value)) }
      assert_includes error.message, 'intent task_understanding'
    end
  end

  def test_each_structured_field_is_one_nonempty_line
    [UNDERSTANDING.except('done_when'), UNDERSTANDING.merge('goal' => ''),
     UNDERSTANDING.merge('done_when' => "Two\nlines.")].each do |value|
      error = assert_raises(Shaka::Error) { render('intent' => INTENT.merge('task_understanding' => value)) }
      assert_match(/intent task_understanding (goal|done_when)/, error.message)
    end
  end

  def test_unknown_structured_fields_are_refused
    value = UNDERSTANDING.merge('original' => 'The raw prompt.')

    error = assert_raises(Shaka::Error) { render('intent' => INTENT.merge('task_understanding' => value)) }
    assert_includes error.message, 'unknown keys: original'
  end

  def test_supplying_an_understanding_does_not_allow_the_original_prompt
    provenance = PUBLIC_PROVENANCE.merge('initial_prompt' => 'Private original prompt.')

    error = assert_raises(Shaka::Error) { render('provenance' => provenance) }
    assert_includes error.message, 'initial_prompt must be EXCLUDED'
  end

  private

  def render(changes = {})
    content = PublicationRegressionTest.new(name).description_content(
      'intent' => INTENT.merge('task_understanding' => UNDERSTANDING), **changes
    )
    Shaka::Publication.description(content)
  end
end
