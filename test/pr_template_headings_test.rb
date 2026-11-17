# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/pr_template'

class PrTemplateHeadingsTest < Minitest::Test
  def test_template_headings_skip_comments_code_and_other_levels
    template = <<~MARKDOWN
      ## Summary
      <!-- Describe the change.
      ## Not a heading -->
      ## Shaka ##
      ```text
      ## Inside a fence
      ```
      ### Deeper
      #Missing space
         ## Indented
      ~~~~
      ## Inside a longer fence
      ~~~
      ## Still inside
      ~~~~
      ## Deployment
    MARKDOWN
    assert_equal %w[Summary Shaka Indented Deployment], Shaka::PrTemplate.headings(template)
  end

  def test_comment_syntax_inside_a_code_block_hides_nothing
    assert_equal %w[Shaka Rollout], Shaka::PrTemplate.headings("```html\n<!--\n```\n## Shaka\n## Rollout\n")
  end

  def test_only_a_bare_fence_closes_a_code_block
    assert_empty Shaka::PrTemplate.headings("```text\n```example\n## Shaka\n```\n")
  end

  def test_comments_on_a_heading_line
    template = "<!-- note --> ## Hidden\n## Summary <!-- what changed -->\nText <!-- open\n## Inside\n-->\n## Shown\n"
    assert_equal %w[Summary Shown], Shaka::PrTemplate.headings(template)
  end

  def test_a_comment_opened_after_another_closes_still_hides_headings
    template = "<!-- first comment\n--> <!-- second comment\n## Shaka\n-->\n## Summary\n"
    assert_equal %w[Summary], Shaka::PrTemplate.headings(template)
  end

  def test_comment_syntax_in_inline_code_hides_nothing
    assert_equal %w[Shaka], Shaka::PrTemplate.headings("Write `<!--` before notes.\n## Shaka\n")
  end

  def test_template_headings_read_windows_line_endings
    template = "## Summary\r\n```\r\n## Code\r\n```\r\n## Shaka Inline\r\n"
    assert_equal ['Summary', 'Shaka Inline'], Shaka::PrTemplate.headings(template)
  end
end
