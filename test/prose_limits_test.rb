# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/prose_limits'

# A description or walkthrough shaped as a wall of text is refused before publication.
class ProseLimitsTest < Minitest::Test
  LIMITS = Shaka::ProseLimits.new

  def test_refuses_a_sentence_past_the_word_limit
    error = assert_raises(Shaka::Error) { verify(html(sentence(36))) }

    assert_includes error.message, 'a sentence has 36 words (limit 35)'
    verify(html(sentence(35)))
  end

  def test_refuses_a_paragraph_past_the_word_limit
    error = assert_raises(Shaka::Error) { verify(html(Array.new(5) { sentence(21) }.join(' '))) }

    assert_includes error.message, 'a paragraph has 105 words (limit 100)'
    verify(html(Array.new(5) { sentence(20) }.join(' ')))
  end

  def test_paragraphs_and_list_items_are_measured_separately
    verify(html(*Array.new(5) { sentence(21) }))
    verify("<ul>\n#{Array.new(5) { "<li>#{sentence(21)}</li>" }.join("\n")}\n</ul>")
  end

  def test_collapsed_and_non_prose_content_is_not_measured
    wall = Array.new(20) { sentence(40) }.join(' ')
    hidden = %w[details pre table h2 blockquote].map { |tag| "<#{tag}>#{wall}</#{tag}>" }

    verify([html('Short summary.'), *hidden].join("\n"))
  end

  def test_code_spans_and_link_targets_count_as_what_the_reader_sees
    code = "<code>#{Array.new(40, 'token').join(' ')}</code>"
    link = %(<a href="https://github.com/o/r/pull/1#pullrequestreview-#{'9' * 40}">the walkthrough</a>)

    verify(html("Read #{code} beside #{link}."))
    verify(html("#{code} starts this sentence. #{sentence(33)}"))
  end

  def test_the_description_budget_grows_with_the_change_up_to_a_cap
    words180 = paragraphs(9)
    error = assert_raises(Shaka::Error) { LIMITS.verify!(words180, kind: :description, changed_lines: 6) }

    assert_includes error.message, 'the visible prose has 180 words (limit 174 for 6 changed lines)'
    LIMITS.verify!(words180, kind: :description, changed_lines: 8)
    assert_raises(Shaka::Error) { LIMITS.verify!(paragraphs(16), kind: :description, changed_lines: 5_000) }
  end

  def test_the_walkthrough_budget_grows_with_the_change_without_a_cap
    assert_raises(Shaka::Error) { LIMITS.verify!(paragraphs(9), kind: :walkthrough, changed_lines: 6) }
    LIMITS.verify!(paragraphs(40), kind: :walkthrough, changed_lines: 5_000)
  end

  def test_an_unknown_change_size_keeps_the_fixed_limits
    LIMITS.verify!(paragraphs(16), kind: :walkthrough, changed_lines: nil)
    error = assert_raises(Shaka::Error) { LIMITS.verify!(paragraphs(16), kind: :description, changed_lines: nil) }

    assert_includes error.message, 'the visible prose has 320 words (limit 300)'
  end

  def test_the_refusal_quotes_the_text_and_says_how_to_fix_it
    error = assert_raises(Shaka::Error) do
      LIMITS.verify!(html("Opening words of a long one #{sentence(40)}"), kind: :walkthrough, changed_lines: 50)
    end

    assert_match(/\AWalkthrough is hard to read: /, error.message)
    assert_includes error.message, '“Opening words of a long one Alpha word…”'
    assert_includes error.message, 'link to the code'
    assert_includes error.message, 'still makes sense without its neighbors'
  end

  # PR #1301 said "accepted on N3"; only the review ledger explains what N3 is.
  def test_refuses_a_bare_review_finding_id
    error = assert_raises(Shaka::Error) { verify(html('Not verified end to end (accepted on N3).', 'See N12 and N4-N5.')) }

    assert_includes error.message, 'ledger ID (N3, N12, N4, N5)'
    assert_includes error.message, 'as code'
  end

  def test_finding_ids_in_collapsed_content_and_lookalikes_are_allowed
    verify([html('Run on N2D instances, v1.N3 and NN3 stay, as do N-3, N2.0, N3-N5D and <code>N2</code>.'),
            '<details><summary>History</summary><p>N3 accepted.</p></details>'].join("\n"))
  end

  private

  def verify(rendered) = LIMITS.verify!(rendered, kind: :walkthrough, changed_lines: 1_000)

  def html(*paragraphs) = paragraphs.map { |text| "<p>#{text}</p>" }.join("\n")

  # A sentence of exactly this many words that begins a new sentence when joined.
  def sentence(words) = "Alpha #{Array.new(words - 2, 'word').join(' ')} end."

  def paragraphs(count) = html(*Array.new(count) { sentence(20) })
end
