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
    assert_match(/\d+\.\d percent of the shorter summary's eight-word runs/, error.message)
  end

  # Whichever of the pair publishes second, one copied sentence reads the same.
  def test_one_copied_sentence_is_refused_from_either_direction
    long = "#{DESCRIPTION} #{'Unrelated wording carries this summary past two hundred separate runs. ' * 12}"
    assert_raises(Shaka::Error) { check(long, WALKTHROUGH) }
    assert_raises(Shaka::Error) { check(WALKTHROUGH, long, 'walkthrough') }
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

  # Tokenizing ASCII only would hand any other script a silent exemption.
  def test_copied_prose_outside_the_ascii_range_is_refused
    copied = 'Загрузчик отклоняет неизвестный режим обзора до начала рабочего процесса.'
    error = assert_raises(Shaka::Error) { check("#{copied} Мейнтейнеры сливают.", "#{copied} Схема поднимает.") }
    assert_includes error.message, 'This description repeats'
  end

  # Every pair the helper renders carries the same identity line and the same
  # walkthrough heading, so counting them reports copying that nobody wrote.
  def test_the_helper_s_own_identity_line_and_headings_are_not_counted
    identity = '🤖 Claude · Anthropic · claude-opus-5 · medium'
    check("#{identity}\n\n## Code Walkthrough\n\nMaintainers can merge without opening the diff today.",
          "#{identity}\n\n# Code Walkthrough\n\nMaintainers can read why the loader raises early.")
  end

  # GitHub renders an unclosed fence as code to the end of the body, so it is not prose.
  def test_an_unclosed_fence_takes_the_rest_of_the_body_with_it
    shared = "```\nbundle exec rubocop --only Metrics and the rest of this command\n"
    check("Merging is safe.\n\n#{shared}", "The loader raises early.\n\n#{shared}")
  end

  # Only the leading identity line is the helper's; a robot emoji mid-body is prose.
  def test_a_robot_emoji_inside_the_body_does_not_exempt_the_line_it_opens
    line = '🤖 The loader now rejects an unknown review mode before the workflow starts.'
    error = assert_raises(Shaka::Error) { check("Merging is safe.\n#{line}", "It raises early.\n#{line}") }
    assert_includes error.message, 'This description repeats'
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
    assert_includes lines('In order to merge, the gate runs. Note that it prints.'), 'in order to, note that'
    assert_includes lines('The gate runs before publication.'), 'filler openers: none'
  end

  # The signal is an opener, so the same phrase inside a sentence is not one.
  def test_a_filler_phrase_used_mid_sentence_is_not_reported
    assert_includes lines('The helper caches the listing in order to avoid a second request.'),
                    'filler openers: none'
  end

  # The list is the repository's own, so it has to carry more than one verb.
  def test_other_bare_third_person_verbs_are_named
    assert_includes lines('Rejects duplicated prose before publication.'), 'diff-shaped'
  end

  # The baseline names this opening in as many words and it is not a bare verb.
  def test_the_documented_this_change_opening_is_named
    assert_includes lines('This change adds an H1 to the walkthrough renderer.'), 'diff-shaped'
  end

  def test_an_advisory_never_raises_on_empty_prose
    assert_includes lines("```ruby\nputs 1\n```"), 'UNKNOWN'
  end
end
