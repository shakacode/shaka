# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/intent_verification'

# https://github.com/shakacode/shaka/issues/846: one PR-wide review effort either asked for more
# care everywhere or understated the few lines that needed close reading.
class PublicationReviewFocusListTest < Minitest::Test
  BLOB = "https://github.com/owner/repo/blob/#{'a' * 40}".freeze
  MERGE = { 'path' => 'lib/merge.rb', 'level' => 4, 'reason' => 'compares the queue base before submitting.',
            'from' => 'def submit', 'block' => true }.freeze
  GUARD = { 'path' => 'lib/guard.rb', 'level' => 5, 'reason' => 'decides who may merge.' }.freeze

  def intent(focus, pull = nil, effort: 2)
    content = { 'intent' => INTENT.merge('review_effort' => effort, 'review_focus' => focus),
                'verification' => VERIFICATION }
    Shaka::IntentVerification.render(content, nil, nil, pull).first
  end

  def resolved(*entries) = { 'shaka_review_focus' => entries }

  def test_entries_follow_review_effort_highest_level_first_with_links_at_the_head
    pull = resolved({ 'url' => "#{BLOB}/lib/merge.rb#L40-L58", 'lines' => [40, 58] },
                    { 'url' => "#{BLOB}/lib/guard.rb", 'lines' => nil })
    rendered = intent([MERGE, GUARD], pull)

    expected = "**Review effort:** 2 of 5, easy: skim the diff.\n\n**Closer reading:**\n" \
               "- 5 of 5: [`lib/guard.rb`](#{BLOB}/lib/guard.rb), decides who may merge.\n" \
               "- 4 of 5: [`lib/merge.rb` lines 40–58](#{BLOB}/lib/merge.rb#L40-L58), " \
               'compares the queue base before submitting.'
    assert_includes rendered, expected
  end

  def test_one_line_range_names_its_line
    pull = resolved({ 'url' => "#{BLOB}/lib/merge.rb#L40", 'lines' => [40, 40] })

    assert_includes intent([MERGE], pull), "[`lib/merge.rb` line 40](#{BLOB}/lib/merge.rb#L40)"
  end

  def test_unresolved_entries_name_the_path_without_a_link
    assert_includes intent([GUARD]), '- 5 of 5: `lib/guard.rb`, decides who may merge.'
  end

  def test_a_path_with_unusual_characters_is_withheld_but_keeps_its_encoded_link
    odd = GUARD.merge('path' => 'lib/`odd`.rb')
    pull = resolved({ 'url' => "#{BLOB}/lib/%60odd%60.rb", 'lines' => nil })

    rendered = intent([odd], pull)
    assert_includes rendered, "[a file whose name is withheld](#{BLOB}/lib/%60odd%60.rb)"
    refute_includes rendered, '`odd`'
  end

  def test_no_entries_add_nothing
    refute_includes intent(nil), 'Closer reading'
    refute_includes intent([]), 'Closer reading'
  end

  def test_a_level_must_ask_for_more_care_than_the_pr_rating
    [2, 1, 6, '4', nil].each do |level|
      error = assert_raises(Shaka::Error) { intent([GUARD.merge('level' => level)]) }
      assert_includes error.message, 'review_focus 1 level'
    end
    assert_includes intent([GUARD.merge('level' => 5)], effort: 4), '- 5 of 5'
  end

  def test_each_entry_needs_a_one_line_reason_and_a_relative_path
    [{ 'reason' => '' }, { 'reason' => "two\nlines" }, { 'path' => '/etc/passwd' }, { 'path' => '../x.rb' },
     { 'path' => nil }].each do |change|
      assert_raises(Shaka::Error) { intent([GUARD.merge(change)]) }
    end
  end

  def test_a_range_end_needs_its_start_and_takes_to_or_block_not_both
    [GUARD.merge('to' => 'end'), GUARD.merge('block' => true), MERGE.merge('to' => 'end'),
     MERGE.merge('block' => 'yes'), GUARD.merge('from' => ' ')].each do |entry|
      assert_raises(Shaka::Error) { intent([entry]) }
    end
  end

  def test_unknown_fields_and_non_lists_are_refused
    error = assert_raises(Shaka::Error) { intent([GUARD.merge('lines' => '40-58')]) }
    assert_includes error.message, 'lines'
    assert_raises(Shaka::Error) { intent(GUARD) }
    assert_raises(Shaka::Error) { intent(['lib/guard.rb']) }
  end
end
