# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/prose_limits'
require 'shaka/supplied_prose'

# Small-PR descriptions were refused for words the helper wrote: its identity, links, metrics and risk lines took
# about 30% of the limit, and a higher risk rating took more (issue #1336). The length limit now counts the prose the
# agent supplied, so the same text fits whatever the rating.
class SuppliedProseTest < Minitest::Test
  def test_counts_the_authors_visible_text_without_the_helpers_labels
    content = { 'summary' => 'Count `only these words` here.',
                'intent' => INTENT.merge('task_understanding' => { 'goal' => 'One two.', 'done_when' => 'Three.' }),
                'verification' => VERIFICATION.merge('summary' => 'See [the run](https://example.com/a/b).') }

    # Summary 3 (a code span is one word), why 8, scope 6, leaves out 4, safe because 7, goal 2, done when 1,
    # verification 3.
    assert_equal 34, Shaka::SuppliedProse.words(content)
  end

  # Words count as written, whatever Markdown makes of them; only a collapsed block's body, addresses and images drop
  # out. A collapsed block's summary label stays, as GitHub shows it.
  def test_words_count_as_written_except_folded_text_addresses_and_images
    body = "Two words ![a diagram](https://example.com/d.png).\n\n<details>\n<summary>Label</summary>\n\n" \
           "Hidden body text.\n\n</details>\n\n| a | b |\n| --- | --- |\n\n> Quoted words\n\nTitle\n====="
    content = { 'summary' => 'One.', 'sections' => [{ 'heading' => 'Heading words', 'body' => body }] }

    # One, two, label, a, b, two quoted, one title.
    assert_equal 9, Shaka::SuppliedProse.words(content)
  end

  # A fenced block's lines count; only an inline span shrinks to one word. Angle brackets are not taken for tags.
  def test_fenced_code_and_angle_brackets_count_as_written
    body = "Run `bin/validate --fast` first.\n\n```ruby\nputs one two\n```\n\nA List<String> and <https://x.test>."

    # Run, code span, first; ```ruby, puts, one, two; A, List<String>, and, the address.
    assert_equal 11, Shaka::SuppliedProse.words('sections' => [{ 'heading' => 'H', 'body' => body }])
  end

  # Shaka's publisher attribution writes the note, so it is helper text.
  def test_the_publisher_note_does_not_count
    assert_equal 1, Shaka::SuppliedProse.words('summary' => 'One.', 'publisher_note' => 'Two more words.')
  end

  def test_the_same_supplied_prose_fits_whatever_the_helper_adds
    content = { 'summary' => sentence(30), 'intent' => INTENT, 'verification' => VERIFICATION }
    limits = Shaka::ProseLimits.new.with_supplied(content)
    helper = Array.new(10) { "<p>#{sentence(30)}</p>" }.join

    limits.verify!("<p>#{sentence(30)}</p>", kind: :description, changed_lines: 6)
    limits.verify!("<p>#{sentence(30)}</p>#{helper}", kind: :description, changed_lines: 6)
  end

  def test_the_refusal_reports_only_the_words_the_author_can_change
    content = { 'summary' => Array.new(6) { sentence(30) }.join(' '), 'intent' => INTENT,
                'verification' => VERIFICATION }
    helper = Array.new(10) { "<p>#{sentence(30)}</p>" }.join

    error = assert_raises(Shaka::Error) do
      Shaka::ProseLimits.new.with_supplied(content).verify!(helper, kind: :description, changed_lines: 6)
    end

    assert_includes error.message, 'the prose you supplied has 205 words (limit 174 for 6 changed lines), 31 words over'
  end

  def test_sentences_the_helper_writes_still_meet_the_sentence_limit
    limits = Shaka::ProseLimits.new.with_supplied('summary' => 'Short.', 'intent' => {}, 'verification' => {})

    error = assert_raises(Shaka::Error) { limits.verify!("<p>#{sentence(36)}</p>", kind: :description, changed_lines: 6) }

    assert_includes error.message, 'a sentence has 36 words (limit 35)'
  end

  def test_a_walkthrough_still_counts_all_its_visible_prose
    limits = Shaka::ProseLimits.new.with_supplied('summary' => 'Short.')
    wall = Array.new(7) { "<p>#{sentence(30)}</p>" }.join

    error = assert_raises(Shaka::Error) { limits.verify!(wall, kind: :walkthrough, changed_lines: 6) }

    assert_includes error.message, 'the visible prose has 210 words'
  end

  private

  def sentence(words) = "Alpha #{Array.new(words - 2, 'word').join(' ')} end."
end

# Every word an author supplies that a reader sees must count, or a new field escapes the limit.
class SuppliedProseCoverageTest < Minitest::Test
  HEAD = 'a' * 40
  # A high rating adds the most helper text to the description.
  HIGH = { 'rating' => 'high', 'level' => 'high', 'areas_hit' => [], 'medium_areas_hit' => [], 'paths_read' => true,
           'max_risk' => 'low', 'reasons' => ['Changes who may merge.'],
           'url' => 'https://github.com/owner/repo/pull/1#issuecomment-9' }.freeze
  # Structured fields the helper validates, links or renders itself are not prose the author writes.
  STRUCTURED = %w[identity publisher_note walkthrough deployment provenance usage head recommendation path when].freeze
  FOCUS = { 'path' => 'lib/merge.rb', 'reason' => 'compares the queue base.' }.freeze

  def test_every_visible_supplied_field_is_counted
    content = marked(rich_content)
    rendered = rough_html(Shaka::Publication.description(content, nil, pull))
    visible = marks(Shaka::VisibleProse.new(rendered).paragraphs.join(' '))
    counted = marks(Shaka::SuppliedProse.markdown(content))

    refute_empty visible
    assert_empty visible - counted, 'a supplied field renders visibly but is not counted'
  end

  private

  def pull = { 'head' => { 'sha' => HEAD }, 'shaka_risk' => HIGH }

  def rich_content # rubocop:disable Metrics/MethodLength
    intent = INTENT.merge('user_impact' => 'Impact.', 'root_cause' => 'Cause.',
                          'task_understanding' => { 'goal' => 'Goal.', 'done_when' => 'Done.' },
                          'review_focus' => [FOCUS])
    { 'identity' => PublicationRegressionTest::IDENTITY, 'publisher_note' => 'Note.', 'summary' => 'A summary.',
      'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'deployment' => 'none',
      'steps_besides_merging' => [{ 'when' => 'after merge', 'step' => 'Step.', 'who' => 'Who.', 'where' => 'Where.',
                                    'verify' => 'Verify.' }],
      'decisions' => ['Decide.'],
      'checkpoint' => { 'head' => HEAD, 'recommendation' => 'Merge', 'next_action' => 'Next.' },
      'intent' => intent, 'risk_record' => { 'summary' => 'Record.', 'body' => 'Record body.' },
      'verification' => VERIFICATION.merge('summary' => 'Ran `x`.', 'not_verified' => 'Gap.',
                                           'merge_limitations' => 'Limit.'),
      'sections' => [{ 'heading' => 'Notes', 'body' => 'Section.' }],
      'table' => { 'columns' => %w[Check], 'rows' => [%w[Row.]] },
      'details' => [{ 'summary' => 'Fold.', 'body' => 'Fold body.' }],
      'provenance' => PUBLIC_PROVENANCE, 'usage' => PublicationRegressionTest::USAGE_OBJECT }
  end

  # Each supplied prose string gains a unique marker word, so a visible one can be traced to its field.
  def marked(value, path = [])
    case value
    when Hash then value.to_h { |key, item| [key, prose_key?(key) ? marked(item, path + [key]) : item] }
    when Array then value.each_with_index.map { |item, index| marked(item, path + [index]) }
    when String then "Mark#{path.join.hash.abs.to_s(36)}x #{value}"
    else value
    end
  end

  def prose_key?(key) = !STRUCTURED.include?(key)

  def marks(text) = text.scan(/Mark[0-9a-z]+x/).uniq

  # Enough of GitHub's rendering for VisibleProse: headings and tables become their hidden tags, other blocks
  # paragraphs.
  def rough_html(markdown)
    markdown.split(/\n\s*\n/).map do |block|
      next block if block.start_with?('<')
      next "<h2>#{block}</h2>" if block.start_with?('#')
      next '<table></table>' if block.start_with?('|')

      "<p>#{block}</p>"
    end.join("\n")
  end
end
