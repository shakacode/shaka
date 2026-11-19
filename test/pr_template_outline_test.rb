# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/pr_template'

class PrTemplateOutlineTest < Minitest::Test
  MARKER = Shaka::PrTemplate::MARKER

  def test_outline_reads_left_edge_headings_and_the_marker_line
    template = "## Rollout\n<!-- How to roll out. -->\n\n<!-- shaka -->\n\n## Changelog\n"
    assert_equal ['Rollout', MARKER, 'Changelog'], outline(template)
    assert_equal ['Summary', MARKER], outline("## Summary\r\n  <!-- shaka -->  \r\n")
  end

  # Anything looser than the strict format is not read, so nothing is guessed.
  def test_outline_ignores_what_the_format_does_not_allow
    template = "   ## Indented\n### Deeper\n#Missing space\n##\n<!-- Shaka -->\n<!-- shaka: here -->\n## Kept\n"
    assert_equal ['Kept'], outline(template)
  end

  def test_code_blocks_hold_no_headings_or_marker
    template = "```markdown\n## In code\n<!-- shaka -->\n```\n~~~~\n## In tildes\n~~~\n## Still in\n~~~~\n" \
               "```npm test```\n## After\n"
    assert_equal ['After'], outline(template)
  end

  def test_code_fences_may_sit_up_to_three_spaces_in
    assert_equal ['Rollout', MARKER], outline("```\n## In code\n  ```\n## Rollout\n<!-- shaka -->\n")
    assert_equal ['After'], outline("   ~~~\n## In tildes\n    ~~~\n~~~\n## After\n")
  end

  def test_comments_that_start_a_line_hold_no_headings_or_marker
    template = "<!-- A note\n## In a comment\n<!-- shaka -->\n-->\n<!-->\n## After\n"
    assert_equal ['After'], outline(template)
  end

  def test_check_shows_the_order_and_repeats_only_when_the_marker_is_present
    assert_empty Shaka::PrTemplate.check(%w[Rollout Changelog])
    notes = Shaka::PrTemplate.check(['Rollout', MARKER, 'Rollout', MARKER])
    assert_equal ["Shaka orders this template's descriptions as: Rollout, Shaka's sections.",
                  'The template repeats `## Rollout`; Shaka uses the first.',
                  'The template repeats <!-- shaka -->; Shaka uses the first.'], notes
  end

  private

  def outline(text) = Shaka::PrTemplate.outline(text)
end
