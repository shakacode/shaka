# frozen_string_literal: true

require_relative 'publication_human_comments_test'

# A quotation leaves out what GitHub renders as code, and keeps the prose around it.
class HumanCommentCodeBlocksTest < Minitest::Test
  include HumanCommentsFixture

  def test_a_fence_of_four_backticks_hides_its_code_and_closes_only_on_four_or_more
    body = "Try:\n\n````md\n```ruby\nsecret_line = 1\n```\n`````\n\nThanks."
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', body)]))

    assert_includes rendered, '[“Try\\: Thanks\\.”]'
  end

  def test_a_tilde_fence_closes_only_on_tildes
    body = "Try:\n~~~~\n```\nsecret_line = 1\n~~~\n~~~~~\nThanks."
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', body)]))

    assert_includes rendered, '[“Try\\: Thanks\\.”]'
  end

  def test_an_indented_code_block_is_not_quoted_but_an_indented_paragraph_line_is
    code = "Please change:\n\n    secret_line = 1\n\tother = 2\n\nThanks."
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', code),
                                                issue_comment(2, 'ann', "Please change\n    this line.")]))

    assert_includes rendered, '[“Please change\\: Thanks\\.”]'
    assert_includes rendered, '[“Please change this line\\.”]'
  end

  def test_a_closing_fence_indented_deeper_than_its_opener_and_three_spaces_does_not_close_it
    rendered = describe(packet(issue_comments: [
                                 issue_comment(1, 'ann', "Run:\n```\n    ```\nsecret_line = 1\n```\nThanks."),
                                 issue_comment(2, 'ann', "Run:\n   ```\n    ```\nsecret_line = 1\n```\nThanks.")
                               ]))

    refute_includes rendered, 'secret'
    assert_equal 2, rendered.scan('[“Run\\: Thanks\\.”]').size
  end

  def test_code_in_a_list_or_after_a_rule_or_heading_is_hidden
    bodies = ["1. Step:\n    ```\n    secret_line = 1\n    ```\nDone.",
              "- Item\n\n```\n    ```\nsecret_line = 1\n```\nDone.", "- Item\n\n      secret_line = 1\n\nDone.",
              "Notes\n\n* * *\n\n    secret_line = 1\n\nDone.", "# Error\n    secret_line = 1\nDone.",
              "Notes\n***\n    secret_line = 1\nDone.", "Title\n===\n    secret_line = 1\nDone.",
              "Title\n--\n    secret_line = 1\nDone.", "1. ```\n   secret_line = 1\n   ```\nDone."]
    comments = bodies.each_with_index.map { |body, id| issue_comment(id, 'ann', body) }
    rendered = describe(packet(issue_comments: comments))

    refute_includes rendered, 'secret'
    assert_equal bodies.size, rendered.scan(/Done\\\.”\]/).size
  end

  def test_a_rule_of_mixed_markers_is_text_and_an_indented_line_after_it_continues_the_paragraph
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', "Please keep\n*-*\n    this line.")]))

    assert_includes rendered, '[“Please keep \\*\\-\\* this line\\.”]'
  end

  def test_a_list_item_keeps_its_indented_paragraph_and_a_fence_ends_with_its_item
    bodies = { "- Please change:\n\n    this behavior." => '\\- Please change\\: this behavior\\.',
               "- ```\n  secret_line = 1\n\nPlease split this." => 'Please split this\\.',
               "Note\n    ```\nmore text" => 'Note \\`\\`\\` more text' }
    comments = bodies.keys.each_with_index.map { |body, id| issue_comment(id, 'ann', body) }
    rendered = describe(packet(issue_comments: comments))

    refute_includes rendered, 'secret'
    bodies.each_value { |said| assert_includes rendered, "[“#{said}”]" }
  end

  def test_a_fence_in_a_later_list_item_hides_its_code
    body = "1. a\n2. ```\n   secret_line = 1\n   ```\n3. c"
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', body)]))

    refute_includes rendered, 'secret'
    assert_includes rendered, '[“1\\. a 3\\. c”]'
  end

  def test_an_unindented_fence_after_a_list_item_s_fence_opens_a_new_one
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', "1. ```\n   x\n```\nsecret_line = 1\nDone.")]))

    refute_includes rendered, 'secret'
    assert_includes rendered, "[Code or quoted text only](#{URL}#issuecomment-1)"
  end

  def test_a_fence_inside_an_indented_code_block_opens_nothing
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', "Run:\n\n    ```\nThen retry.")]))

    assert_includes rendered, '[“Run\\: Then retry\\.”]'
  end
end
