# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/visible_prose'

# Markdown formatting must not change which prose counts or where sentences end.
class VisibleProseTest < Minitest::Test
  def test_a_details_tag_inside_code_does_not_hide_later_prose
    markdown = "Use `<details>` for supporting evidence.\n\nThe next paragraph stays visible."

    assert_equal [['Use Code for supporting evidence.'], ['The next paragraph stays visible.']], paragraphs(markdown)
  end

  def test_emphasis_and_quotes_do_not_join_sentences
    markdown = 'The helper refuses it. **Reviewers** see the code. "Quoted" text counts. _Why_ matters.'

    assert_equal 4, paragraphs(markdown).first.size
  end

  private

  def paragraphs(markdown) = Shaka::VisibleProse.new(markdown).paragraphs
end
