# frozen_string_literal: true

require_relative 'publication_test'

class PublicationTaskUnderstandingTest < Minitest::Test
  UNDERSTANDING = "Let customers export the orders matching their current filters.\n\n" \
                  'Success means the CSV contains the same orders as the page.'
  SHOWN = '**Task as understood:** Let customers export the orders matching their current filters.<br>' \
          'Success means the CSV contains the same orders as the page.'

  def test_the_task_understanding_shows_open_beside_its_source
    rendered = render

    assert_includes rendered, "**Task:** Codex prompt\n\n#{SHOWN}\n\n**Safe because:**"
    assert_equal 1, rendered.scan('**Task as understood:**').size
    refute_includes rendered, '<summary>Task as understood</summary>'
  end

  def test_paragraphs_stay_inside_one_labeled_item
    understanding = "  First paragraph.\n \nSecond paragraph.\n\n\nThird paragraph.\n"
    rendered = render('intent' => INTENT.merge('task_understanding' => understanding))

    assert_includes rendered, "**Task as understood:** First paragraph.<br>Second paragraph.<br>Third paragraph.\n\n"
  end

  def test_the_same_understanding_can_accompany_an_issue_or_another_agent
    issue = PUBLIC_PROVENANCE.merge('task_source' => 'issue', 'task_number' => 1234)
    assert_includes render('provenance' => issue), "**Task:** GitHub #1234\n\n#{SHOWN}"
    claude = PublicationRegressionTest::IDENTITY.merge('agent' => 'Claude Code')
    assert_includes render('identity' => claude), "**Task:** Claude prompt\n\n#{SHOWN}"
  end

  def test_older_callers_can_omit_the_understanding
    refute_includes render('intent' => INTENT), 'Task as understood'
  end

  def test_supplied_understanding_requires_nonempty_text_with_real_line_breaks
    ['', ' ', 17, [], 'Outcome.\nSuccess.'].each do |value|
      error = assert_raises(Shaka::Error) { render('intent' => INTENT.merge('task_understanding' => value)) }
      assert_includes error.message, 'intent task_understanding'
    end
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
