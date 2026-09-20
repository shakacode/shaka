# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication'

PUBLIC_PROVENANCE = { 'task_source' => 'description', 'initial_prompt' => 'EXCLUDED',
                      'workflow_version' => 'v1.2.3',
                      'requested_model' => 'gpt-5.6-terra', 'requested_effort' => 'medium',
                      'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
                      'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium' }.freeze

# Reproduces the presentation failures observed on real published pull requests.
class PublicationRegressionTest < Minitest::Test
  IDENTITY = { 'agent' => 'Codex', 'provider' => 'OpenAI', 'model' => 'gpt-5.6-terra', 'effort' => 'low' }.freeze
  TABLE = { 'columns' => %w[Check Commit Result], 'rows' => [%w[bin/validate abc123 pass]] }.freeze
  USAGE = { 'summary' => 'Usage',
            'body' => "| Provider | Native total |\n| --- | ---: |\n| openai | 1 |" }.freeze
  WALKTHROUGH = 'https://github.com/shakacode/shaka/pull/137#pullrequestreview-5258565629'

  def description_content(**changes)
    { 'identity' => IDENTITY, 'summary' => 'A summary.', 'walkthrough' => WALKTHROUGH, 'table' => TABLE,
      'provenance' => PUBLIC_PROVENANCE, 'details' => [USAGE] }.merge(changes)
  end

  # https://github.com/shakacode/shaka/pull/37 published its whole description as one
  # line containing literal backslash-n sequences instead of paragraph breaks.
  def test_escaped_newlines_in_supplied_text_are_reported_before_publication
    content = description_content(
      'summary' => 'Resolves #34 with post-rename maintenance.\n\n## Validation\n\nbin/validate passed.'
    )
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(content) }
    assert_includes error.message, 'escape sequence'
  end

  def test_real_newlines_and_unicode_and_code_escapes_are_preserved
    body = "First line.\n\nSecond café 🤖 line.\n\n```ruby\nputs \"a\\nb\"\n```\n\nUse `\\n` to separate."
    rendered = Shaka::Publication.description(
      description_content('sections' => [{ 'heading' => 'Detail', 'body' => body }])
    )
    assert_includes rendered, 'Second café 🤖 line.'
    assert_includes rendered, 'puts "a\nb"'
    assert_includes rendered, 'Use `\n` to separate.'
  end

  # https://github.com/shakacode/shaka/pull/38 published a ten-column usage table with an
  # eleven-column separator, so GitHub rendered zero tables and showed the pipes as text.
  def test_table_separator_always_matches_the_column_count
    columns = %w[Provider Model Routed Effort Input Cached Output Reasoning Writes Total]
    rendered = Shaka::Publication.description(
      description_content('table' => { 'columns' => columns, 'rows' => [%w[openai sol UNKNOWN medium 1 2 3 4 5 6]] })
    )
    widths = visible_table_widths(rendered)
    assert_equal [columns.size] * 3, widths
  end

  def visible_table_widths(markdown)
    markdown.split('<details>', 2).first.lines.select { |line| line.start_with?('|') }.map do |line|
      line.strip.delete_prefix('|').delete_suffix('|').split('|').size
    end
  end

  def test_row_width_mismatch_is_a_focused_diagnostic_not_a_broken_table
    content = description_content('table' => { 'columns' => %w[A B C], 'rows' => [%w[1 2]] })
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(content) }
    assert_includes error.message, '3'
    assert_includes error.message, '2'
  end

  # https://github.com/shakacode/shaka/pull/71 published validation and usage as prose,
  # so GitHub rendered no tables in the managed description.
  def test_a_description_without_a_table_is_refused
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(description_content.except('table')) }
    assert_includes error.message, 'table'
  end

  def test_usage_details_restated_as_prose_are_refused
    prose = { 'summary' => 'Final native usage snapshot',
              'body' => 'Native usage is PARTIAL: 70 responses from the latest Codex turn.' }
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(description_content('details' => [prose])) }
    assert_includes error.message, 'usage'
  end

  def test_a_separator_line_alone_does_not_count_as_a_usage_table
    decoy = { 'summary' => 'Usage',
              'body' => "Native usage is PARTIAL: 70 responses.\n\n| --- |" }
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(description_content('details' => [decoy])) }
    assert_includes error.message, 'usage'
  end

  def test_a_later_usage_detail_with_a_complete_table_is_accepted
    rendered = Shaka::Publication.description(
      description_content('details' => [
                            { 'summary' => 'Usage notes', 'body' => 'See the snapshot below.' },
                            USAGE
                          ])
    )
    assert_includes rendered, '| openai | 1 |'
  end
end

# Structure the renderer owns so models cannot vary it.
class PublicationStructureTest < Minitest::Test
  IDENTITY = PublicationRegressionTest::IDENTITY

  def render(**changes)
    Shaka::Publication.description(
      { 'identity' => IDENTITY, 'summary' => 'A summary.',
        'walkthrough' => PublicationRegressionTest::WALKTHROUGH,
        'table' => PublicationRegressionTest::TABLE,
        'provenance' => PUBLIC_PROVENANCE,
        'details' => [PublicationRegressionTest::USAGE] }.merge(changes)
    )
  end

  def test_identity_line_leads_the_description
    assert_match(/\A🤖 Codex · OpenAI · gpt-5\.6-terra · low\n\nA summary\.\n/, render)
  end

  def test_sections_become_second_level_headings_separated_by_one_blank_line
    rendered = render('sections' => [{ 'heading' => 'Purpose', 'body' => 'Why.' },
                                     { 'heading' => 'Validation', 'body' => 'How.' }])
    assert_includes rendered, "\n## Purpose\n\nWhy.\n\n## Validation\n\nHow.\n"
    refute_includes rendered, "\n\n\n"
  end

  def test_details_keep_the_blank_lines_github_needs_to_render_their_content
    rendered = render('details' => [PublicationRegressionTest::USAGE,
                                    { 'summary' => 'Rollback', 'body' => "| A |\n| --- |\n| 1 |" }])
    assert_includes rendered, "<details>\n<summary>Rollback</summary>\n\n| A |"
    assert_includes rendered, "| 1 |\n\n</details>"
  end

  def test_missing_or_empty_required_content_is_reported_before_publication
    [{ 'identity' => IDENTITY }, { 'identity' => IDENTITY, 'summary' => '   ' }, { 'summary' => 'A summary.' }]
      .each { |content| assert_raises(Shaka::Error) { Shaka::Publication.description(content) } }
    assert_raises(Shaka::Error) { render('sections' => [{ 'heading' => '', 'body' => 'Why.' }]) }
    error = assert_raises(Shaka::Error) { render('details' => [{ 'summary' => 'Rollback', 'body' => 'Revert.' }]) }
    assert_includes error.message, 'usage'
  end

  def test_short_replies_stay_short
    rendered = Shaka::Publication.comment({ 'identity' => IDENTITY, 'summary' => 'Fixed in 0a1b2c3.' })
    assert_equal "🤖 Codex · OpenAI · gpt-5.6-terra · low\n\nFixed in 0a1b2c3.\n", rendered
  end

  def test_unknown_identity_fields_are_marked_rather_than_invented
    rendered = Shaka::Publication.comment({ 'identity' => { 'agent' => 'Codex', 'provider' => 'OpenAI' },
                                            'summary' => 'Done.' })
    assert_includes rendered, '🤖 Codex · OpenAI · UNKNOWN · UNKNOWN'
  end

  def test_walkthroughs_carry_their_revision_and_are_not_approvals
    rendered = Shaka::Publication.walkthrough({ 'identity' => IDENTITY, 'summary' => 'What changed.',
                                                'head' => 'a' * 40 })
    assert_includes rendered, 'a' * 40
    assert_includes rendered, 'not an approval'
  end

  # Without this H1, GitHub reviews read as untitled comments instead of the
  # titled COMMENT walkthrough on https://github.com/shakacode/shaka/pull/71#pullrequestreview-5229855190
  def test_walkthroughs_use_an_h1_title_after_identity
    rendered = Shaka::Publication.walkthrough({ 'identity' => IDENTITY, 'summary' => 'What changed.',
                                                'head' => 'a' * 40 })
    assert_match(/\A🤖 Codex · OpenAI · gpt-5\.6-terra · low\n\n# Code Walkthrough\n\nWhat changed.\n/m,
                 rendered)
    refute_includes Shaka::Publication.comment({ 'identity' => IDENTITY, 'summary' => 'Fixed.' }),
                    '# Code Walkthrough'
  end

  def test_a_real_newline_in_a_cell_cannot_split_the_row
    content = { 'identity' => IDENTITY, 'summary' => 'A summary.',
                'walkthrough' => PublicationRegressionTest::WALKTHROUGH,
                'table' => { 'columns' => %w[A B], 'rows' => [%W[one\ntwo three]] },
                'provenance' => PUBLIC_PROVENANCE }
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(content) }
    assert_includes error.message, 'single line'
  end

  def test_a_real_newline_in_a_heading_column_or_details_summary_is_refused
    [{ 'sections' => [{ 'heading' => "A\nB", 'body' => 'Why.' }] },
     { 'table' => { 'columns' => ["A\nB"], 'rows' => [] } },
     { 'details' => [{ 'summary' => "A\nB", 'body' => 'Why.' }] }].each do |part|
      assert_raises(Shaka::Error) { render(**part) }
    end
  end

  def test_tilde_fences_and_multi_backtick_spans_count_as_code
    body = "~~~\nliteral \\n here\n~~~\n\nand ``a \\n b`` inline."
    rendered = render('sections' => [{ 'heading' => 'Detail', 'body' => body }])
    assert_includes rendered, 'literal \n here'
  end

  # https://github.com/shakacode/shaka/issues/56 — a longer delimiter is how GFM
  # puts a shorter backtick run inside an inline span.
  def test_a_multi_backtick_span_may_contain_a_shorter_backtick_run
    body = 'Use ``a `b` \n c`` inline.'
    rendered = render('sections' => [{ 'heading' => 'Detail', 'body' => body }])
    assert_includes rendered, 'Use ``a `b` \n c`` inline.'
  end

  def test_a_details_summary_cannot_close_its_own_disclosure
    rendered = render('details' => [PublicationRegressionTest::USAGE,
                                    { 'summary' => 'Docs for </summary></details> handling', 'body' => 'b' }])
    assert_includes rendered, '<summary>Docs for &lt;/summary&gt;&lt;/details&gt; handling</summary>'
    assert_equal 3, rendered.scan('</summary>').size
    assert_equal 3, rendered.scan('</details>').size
  end

  def test_collections_that_are_not_lists_are_refused_rather_than_crashing
    [{ 'sections' => { 'heading' => 'h' } }, { 'sections' => 42 }, { 'details' => 'text' },
     { 'table' => { 'columns' => 'A', 'rows' => [] } },
     { 'table' => { 'columns' => %w[A], 'rows' => 'nope' } }].each do |part|
      error = assert_raises(Shaka::Error) { render(**part) }
      assert_includes error.message, 'list'
    end
  end
end

# https://github.com/shakacode/shaka/pull/137 buried the walkthrough in the opening
# sentence. Keep a dedicated link after the summary instead of a heading that
# repeats the same words as the link text.
class PublicationWalkthroughLinkTest < Minitest::Test
  def render(walkthrough: PublicationRegressionTest::WALKTHROUGH)
    Shaka::Publication.description(
      { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
        'walkthrough' => walkthrough, 'table' => PublicationRegressionTest::TABLE,
        'provenance' => PUBLIC_PROVENANCE, 'details' => [PublicationRegressionTest::USAGE] }
    )
  end

  def test_descriptions_lead_with_a_code_walkthrough_review_link
    link = PublicationRegressionTest::WALKTHROUGH
    rendered = render

    assert_includes rendered, "A summary.\n\n[Code Walkthrough](#{link})\n"
    refute_includes rendered, '## Code Walkthrough'
    refute_match(/^# Code Walkthrough/, rendered)
  end

  def test_the_walkthrough_link_precedes_other_description_sections
    rendered = render_with_section
    walkthrough_at = rendered.index('[Code Walkthrough](')
    section_at = rendered.index("## Outcome\n")

    refute_nil walkthrough_at
    refute_nil section_at
    assert_operator walkthrough_at, :<, section_at
  end

  def render_with_section
    Shaka::Publication.description(
      { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
        'walkthrough' => PublicationRegressionTest::WALKTHROUGH,
        'sections' => [{ 'heading' => 'Outcome', 'body' => 'What landed.' }],
        'table' => PublicationRegressionTest::TABLE, 'provenance' => PUBLIC_PROVENANCE,
        'details' => [PublicationRegressionTest::USAGE] }
    )
  end

  def test_a_description_without_a_walkthrough_link_reserves_the_placeholder
    rendered = render(walkthrough: nil)

    assert_includes rendered, "A summary.\n\n_Not published yet._"
    refute_includes rendered, '[Code Walkthrough]('
    refute_includes rendered, '## Code Walkthrough'
  end

  def test_a_blank_walkthrough_link_reserves_the_placeholder
    rendered = render(walkthrough: '  ')

    assert_includes rendered, "A summary.\n\n_Not published yet._"
    refute_includes rendered, '[Code Walkthrough]('
    refute_includes rendered, '## Code Walkthrough'
  end

  def test_a_blob_pr_or_issue_comment_url_is_not_a_walkthrough_link
    %w[
      https://github.com/shakacode/shaka/blob/abc/README.md
      https://github.com/shakacode/shaka/pull/137
      https://github.com/shakacode/shaka/pull/137#issuecomment-5746446012
    ].each do |url|
      error = assert_raises(Shaka::Error) { render(walkthrough: url) }
      assert_includes error.message, 'walkthrough'
    end
  end
end

class PublicationProvenanceRequirementTest < Minitest::Test
  # Catches a renderer that accepts the structured metadata but silently drops it,
  # leaving a PR without the route evidence needed for later comparison.
  def test_description_renders_public_safe_execution_provenance
    content = { 'identity' => PublicationStructureTest::IDENTITY, 'summary' => 'A summary.',
                'walkthrough' => PublicationRegressionTest::WALKTHROUGH,
                'table' => PublicationRegressionTest::TABLE, 'provenance' => PUBLIC_PROVENANCE,
                'details' => [PublicationRegressionTest::USAGE] }
    rendered = Shaka::Publication.description(content)

    assert_includes rendered, '<summary>Execution provenance</summary>'
    assert_includes rendered, '| Machine alias |'
    assert_includes rendered, '| Requested route | gpt-5.6-terra / medium |'
    refute_includes rendered, '| Initial prompt |'
    refute_includes rendered, '| Observed route |'
  end

  def test_description_refuses_missing_execution_provenance
    content = { 'identity' => PublicationStructureTest::IDENTITY, 'summary' => 'A summary.',
                'walkthrough' => PublicationRegressionTest::WALKTHROUGH,
                'table' => PublicationRegressionTest::TABLE,
                'details' => [PublicationRegressionTest::USAGE] }
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(content) }

    assert_includes error.message, 'provenance'
  end
end
