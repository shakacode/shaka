# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/writing'

# The duplication rule is the writing baseline's one structural claim, so it refuses.
class WritingDuplicationTest < Minitest::Test
  COPIED = 'The loader now rejects an unknown review mode before the workflow starts.'
  DESCRIPTION = "#{COPIED} Maintainers can merge without reading the diff.".freeze
  WALKTHROUGH = "#{COPIED} ReviewSchema raises while the contract is still being read.".freeze

  def check(text, sibling, label = 'description')
    Shaka::Writing::Duplication.new(text, sibling).check(label)
  end

  def test_copied_sentence_between_the_pair_is_refused
    error = assert_raises(Shaka::Error) { check(DESCRIPTION, WALKTHROUGH) }
    assert_includes error.message, 'share the subject, never the sentences'
  end

  # The writer has to see which runs to re-resolve, not only a percentage.
  def test_refusal_quotes_the_shared_runs_and_its_own_ratio
    error = assert_raises(Shaka::Error) { check(DESCRIPTION, WALKTHROUGH) }
    assert_includes error.message, 'rejects an unknown review mode before the workflow'
    assert_match(/\d+\.\d percent of its own eight-word runs/, error.message)
  end

  def test_the_named_surface_appears_in_the_refusal
    error = assert_raises(Shaka::Error) { check(WALKTHROUGH, DESCRIPTION, 'walkthrough') }
    assert_includes error.message, 'This walkthrough repeats'
  end

  def test_prose_that_shares_only_its_subject_is_published
    summary = 'Maintainers can now merge an unknown review mode without reading the diff at all.'
    detail = 'ReviewSchema raises while the repository contract is still being read, which is why.'
    check(summary, detail)
  end

  # A first walkthrough published before any description has nothing to compare.
  def test_an_absent_sibling_never_blocks_publication
    check(DESCRIPTION, nil)
    check(DESCRIPTION, '')
  end

  # Both summaries cite the same commit, and neither writer composed those characters.
  def test_shared_code_and_link_targets_are_not_counted_as_copied_prose
    url = 'https://github.com/shakacode/shaka/blob/abc/skills/shaka/lib/shaka/publication.rb#L21'
    code = "```ruby\nraise Error, 'Publication description requires a table row here now'\n```"
    check("Maintainers merge without reading the diff.\n\n#{code}\n\n[what the gate reads](#{url})\n#{url}",
          "ReviewSchema raises while the contract loads.\n\n#{code}\n\n[where stripping happens](#{url})\n#{url}")
  end
end

# Everything else only prints, because a gated metric teaches the writer to dodge it.
class WritingAdvisoryTest < Minitest::Test
  def lines(text) = Shaka::Writing::Advisory.new(text).lines.join("\n")

  def test_reading_grade_is_reported_with_the_targets_it_is_measured_against
    assert_match(/reading grade \d+\.\d; the baseline targets grade 8/, lines('The loader reads the file.'))
  end

  def test_a_diff_shaped_opening_sentence_is_named
    assert_includes lines('Adds a duplication check and makes it refuse.'), 'diff-shaped'
  end

  def test_an_outcome_first_opening_sentence_passes
    assert_includes lines('Maintainers now see which runs to re-resolve.'), 'opens with a subject'
  end

  # The helper writes the identity line and the walkthrough heading, not the writer.
  def test_the_identity_line_and_headings_are_not_read_as_the_opening_sentence
    body = "🤖 Claude · Anthropic · opus 5 · medium\n\n# Code Walkthrough\n\nAdds a check.\n"
    assert_includes lines(body), 'diff-shaped'
  end

  def test_hedging_and_decorative_emphasis_are_counted_per_hundred_words
    assert_match(/hedging \d+\.\d and decorative emphasis \d+\.\d per 100 words/, lines('It **might** work.'))
  end

  def test_filler_openers_are_listed_and_absence_is_stated
    assert_includes lines('In order to merge, note that the gate runs.'), 'in order to, note that'
    assert_includes lines('The gate runs before publication.'), 'filler openers: none'
  end

  def test_an_advisory_never_raises_on_empty_prose
    assert_includes lines("```ruby\nputs 1\n```"), 'UNKNOWN'
  end
end
