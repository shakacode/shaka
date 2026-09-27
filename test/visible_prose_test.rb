# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/visible_prose'

# Markdown formatting must not change which prose counts or where sentences end.
class VisibleProseTest < Minitest::Test
  def test_a_details_tag_inside_code_does_not_hide_later_prose
    markdown = "Use `<details>` for supporting evidence.\n\nThe next paragraph stays visible."

    assert_equal [['Use Code for supporting evidence.'], ['The next paragraph stays visible.']], paragraphs(markdown)
  end

  def test_a_details_tag_inside_a_comment_does_not_hide_later_prose
    markdown = "<!-- <details> -->\n\nThe next paragraph stays visible."

    assert_equal [['The next paragraph stays visible.']], paragraphs(markdown)
  end

  def test_emphasis_quotes_and_lowercase_names_do_not_join_sentences
    markdown = 'The helper refuses it. **Reviewers** see the code. "Quoted" text counts. iOS builds pass.'

    assert_equal 4, paragraphs(markdown).first.size
  end

  def test_indented_code_is_hidden_but_indented_list_items_are_prose
    markdown = "Run this:\n\n    bundle exec rake test\n    echo done\n\n- Item\n    - Nested item"

    assert_equal [['Run this:'], ['Item'], ['Nested item']], paragraphs(markdown)
  end

  private

  def paragraphs(markdown) = Shaka::VisibleProse.new(markdown).paragraphs
end
