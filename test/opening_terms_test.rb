# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative '../skills/shaka/lib/shaka/opening_check'
require_relative '../skills/shaka/lib/shaka/opening_prose'
require_relative 'opening_check_test_helpers'

# Words a maintainer new to the tool would not follow, read from a description's visible prose.
class OpeningTermsTest < Minitest::Test
  include OpeningCheckTestHelpers

  OUTCOME = 'Pull requests for Linear and other tracker issues now link to their issue.'
  COMMAND = '`shaka merge` now stops before submitting a PR.'

  def test_flags_a_term_in_description_prose_and_gives_its_plain_wording
    term = { term: 'blocked attestation', where: 'Safe because', plain_wording: 'a checkpoint marked blocked' }
    with_claude(parse('Pull requests', true).merge(unclear_terms: [term])) do |root, trace|
      result = check(OUTCOME, root:, prose: 'Safe because: the path keeps its blocked attestation.')
      assert_equal 'flagged', result.fetch('status'), result.inspect
      ['"blocked attestation" in Safe because', '"a checkpoint marked blocked"',
       'Reword any they would stumble on'].each { assert_includes result.fetch('reason'), it }
      assert_includes JSON.parse(File.read(trace)).fetch('prompt'), 'its blocked attestation'
    end
  end

  def test_reports_both_problems_when_the_first_sentence_and_prose_are_flagged
    term = { term: 'that head', where: 'Why', plain_wording: 'that commit' }
    with_claude(parse('shaka merge', false).merge(unclear_terms: [term])) do |root, _trace|
      reason = check(COMMAND, root:, prose: 'Why: that head failed.').fetch('reason')
      assert_includes reason, '"shaka merge"'
      assert_includes reason, '"that head" in Why'
    end
  end

  def test_passes_description_prose_with_no_unclear_terms
    with_claude(parse('Pull requests', true).merge(unclear_terms: [])) do |root, _trace|
      assert_equal 'passed', check(OUTCOME, root:, prose: 'Why: a reviewer asked.').fetch('status')
    end
  end

  def test_description_prose_with_a_parse_missing_or_misshaping_terms_is_not_checked
    [parse('Pull requests', true), parse('Pull requests', true).merge(unclear_terms: [{ term: 'x' }])].each do |output|
      with_claude(output) do |root, _trace|
        assert_equal 'not_checked', check(OUTCOME, root:, prose: 'Why: a reviewer asked.').fetch('status')
      end
    end
  end

  def test_keeps_the_first_eight_terms_so_a_noisy_parse_stays_readable
    terms = (1..9).map { |n| { term: "term#{n}", where: 'Why', plain_wording: 'plain' } }
    with_claude(parse('Pull requests', true).merge(unclear_terms: terms)) do |root, _trace|
      reason = check(OUTCOME, root:, prose: 'Why: a reviewer asked.').fetch('reason')
      assert_includes reason, '"term8"'
      refute_includes reason, '"term9"'
    end
  end

  # A walkthrough sends no prose, so its prompt and verdict stay about the opening alone.
  def test_an_opening_without_prose_ignores_terms_and_does_not_ask_for_them
    term = { term: 'attestation', where: 'Opening', plain_wording: 'record' }
    with_claude(parse('Pull requests', true).merge(unclear_terms: [term])) do |root, trace|
      assert_equal 'passed', check(OUTCOME, root:).fetch('status')
      refute_includes JSON.parse(File.read(trace)).fetch('prompt'), 'Return an unclear_terms'
    end
  end

  def test_a_prose_change_is_a_new_check_and_the_same_prose_is_cached
    with_claude(parse('Pull requests', true).merge(unclear_terms: [])) do |root, trace|
      check(OUTCOME, root:, prose: 'Why: first.')
      File.delete(trace)
      check(OUTCOME, root:, prose: 'Why: first.')
      refute_path_exists trace, 'unchanged prose must reuse the verdict'
      check(OUTCOME, root:, prose: 'Why: second.')
      assert_path_exists trace, 'changed prose must call the model again'
    end
  end

  def test_visible_prose_holds_what_a_reader_sees_and_leaves_out_what_folds
    intent = { 'why' => 'Reviewers asked.', 'root_cause' => 'A cache.', 'safe_because' => 'Tests cover it.',
               'scope' => 'The cache.', 'review_focus' => [{ 'reason' => 'Touches merge.' }], 'review_effort' => 3 }
    verification = { 'summary' => 'CI passed.', 'merge_limitations' => 'No live merge.',
                     'checks' => ['Ran `bin/test`.'], 'not_verified' => 'A collapsed gap.' }
    assert_equal ['Why: Reviewers asked.', 'Root cause: A cache.', 'Safe because: Tests cover it.', 'Scope: The cache.',
                  'Closer reading: Touches merge.', 'Verification: CI passed.', 'Not verified: No live merge.'],
                 Shaka::OpeningProse.call('intent' => intent, 'verification' => verification).lines(chomp: true)
  end
end
