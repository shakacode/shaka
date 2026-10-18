# frozen_string_literal: true

require_relative 'publication_human_comments_test'

# A quotation leaves out what GitHub renders as code, and keeps the prose around it.
class HumanCommentCodeBlocksTest < Minitest::Test
  include HumanCommentsFixture

  def test_a_fence_closes_only_on_a_run_of_its_own_character_at_least_as_long
    bodies = ["Try:\n\n````md\n```ruby\nsecret_line = 1\n```\n`````\n\nThanks.",
              "Try:\n~~~~\n```\nsecret_line = 1\n~~~\n~~~~~\nThanks.",
              "Try:\n```\n    ```\nsecret_line = 1\n```\nThanks.",
              "Try:\n   ```\n    ```\nsecret_line = 1\n```\nThanks."]

    assert_quoted bodies, 'Try\\: Thanks\\.'
  end

  def test_an_indented_code_block_is_hidden_and_an_indented_paragraph_line_is_quoted
    rendered = quote("Please change:\n\n    secret_line = 1\n\tother = 2\n\nThanks.", "Please change\n    this line.",
                     "Note\n    ```\nmore text", "Run:\n\n    ```\nThen retry.")

    refute_includes rendered, 'secret'
    ['Please change\\: Thanks\\.', 'Please change this line\\.', 'Note \\`\\`\\` more text',
     'Run\\: Then retry\\.'].each { |said| assert_includes rendered, "[“#{said}”]" }
  end

  def test_code_right_after_a_heading_a_rule_or_an_underline_is_hidden
    bodies = ["Notes\n\n* * *\n\n    secret_line = 1\n\nDone.", "# Error\n    secret_line = 1\nDone.",
              "Notes\n***\n    secret_line = 1\nDone.", "Title\n===\n    secret_line = 1\nDone.",
              "Title\n--\n    secret_line = 1\nDone."]

    assert_quoted bodies, nil
  end

  def test_a_rule_of_mixed_markers_or_an_underline_without_a_paragraph_is_text
    rendered = quote("Please keep\n*-*\n    this line.", "Intro\n\n===\n    keep this.")

    assert_includes rendered, '[“Please keep \\*\\-\\* this line\\.”]'
    assert_includes rendered, '[“Intro \\=\\=\\= keep this\\.”]'
  end

  def test_a_short_list_beside_code_needs_the_agent_s_summary
    body = "1. Step:\n    ```\n    secret_line = 1\n    ```\nDone."
    ["- ```\n  secret_line = 1\n\nPlease split this.", "- Item\n\n      secret_line = 1", '-     secret_line = 1',
     '- -     secret_line = 1', '1. -     secret_line = 1', body].each do |listed|
      error = assert_raises(Shaka::Error) { quote(listed) }
      assert_includes error.message, "needs a one-line summary for each longer human comment: #{URL}#issuecomment-0"
    end

    rendered = describe(packet(issue_comments: [issue_comment(0, 'ann', body)]),
                        summaries: { "#{URL}#issuecomment-0" => 'Asks for one step.' })

    refute_includes rendered, 'secret'
    assert_includes rendered, "[Asks for one step\\.](#{URL}#issuecomment-0)"
  end

  def test_an_agent_reply_with_a_list_beside_code_opens_only_with_a_clear_first_paragraph
    reply = "#{IDENTITY}\n\nFixed both:\n\n- the parser\n- its test\n\n```\nsecret_line = 1\n```"
    rendered = describe(packet(inline_comments: [inline(1, 'ann', 'Why?'), inline(2, 'ann', reply)]))

    refute_includes rendered, 'secret'
    assert_equal [["[“Fixed both\\:”](#{URL}#discussion_r2)"]], columns(rendered, 2)
    ["- Fixed the parser\n- Added a test\n\n```\nsecret_line = 1\n```", "```\n- secret_line\n```\nFixed both.",
     "\n    secret_line = 1\n\n- the parser"].each do |body|
      assert_nil Shaka::CommentExcerpt.opening(body)
    end
  end

  def test_a_list_without_code_is_quoted
    assert_includes quote("- First\n- Second"), '[“\\- First \\- Second”]'
  end

  private

  def quote(*bodies)
    describe(packet(issue_comments: bodies.each_with_index.map { |body, id| issue_comment(id, 'ann', body) }))
  end

  def assert_quoted(bodies, said)
    rendered = quote(*bodies)

    refute_includes rendered, 'secret'
    expected = said ? "[“#{said}”]" : /Done\\\.”\]/
    assert_equal bodies.size, rendered.scan(expected).size
  end
end
