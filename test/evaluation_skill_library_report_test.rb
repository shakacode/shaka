# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/skill_library_report'

class EvaluationSkillLibraryReportTest < Minitest::Test
  REPORT = Shaka::Evaluation::SkillLibraryReport

  def library(name, every_session, median, largest)
    { 'library' => name, 'commit' => 'abc', 'skills' => 2, 'commands' => 0, 'every_session' => every_session,
      'median_skill' => { 'name' => 'mid', 'text' => median },
      'largest_skill' => { 'name' => 'big', 'text' => largest } }
  end

  def libraries = [library('one', 'a b', 'c d e', 'c d e'), library('two', 'f', 'g h', 'i j k l')]

  def test_identical_texts_share_one_key
    keys = REPORT.keys(libraries)

    assert_equal ['one every_session', 'one median_skill', 'two every_session', 'two median_skill',
                  'two largest_skill'], keys.values
  end

  # Each text's count is its key's length, so a wrong lookup shows up as a wrong number.
  def counted(keys) = keys.values.to_h { |key| [key, key.length] }

  def test_rows_carry_words_and_each_clis_count_for_the_right_text
    keys = REPORT.keys(libraries)
    failed = { 'tokens' => 'UNKNOWN', 'reason' => 'claude timed out after 300s' }
    counts = [{ 'cli' => 'claude', 'texts' => counted(keys).merge('two largest_skill' => failed) },
              { 'cli' => 'codex', 'tokens' => 'UNKNOWN', 'reason' => 'codex is not installed' }]
    one, two = REPORT.rows(libraries, keys, counts)

    assert_equal [16, 'UNKNOWN'], one['largest_skill'].values_at('claude', 'codex')
    assert_equal [failed, 'UNKNOWN'], two['largest_skill'].values_at('claude', 'codex')
    assert_equal [1, 17], two['every_session'].values_at('words', 'claude')
  end

  def test_words_only_rows_have_no_counts
    rows = REPORT.rows(libraries, REPORT.keys(libraries), nil)

    assert_equal({ 'words' => 2, 'name' => 'mid' }, rows.last['median_skill'])
  end
end
