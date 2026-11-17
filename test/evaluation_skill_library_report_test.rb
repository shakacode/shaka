# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative '../lib/instruction_tokens'
require_relative '../eval/lib/shaka/evaluation/skill_library_report'

class EvaluationSkillLibraryReportTest < Minitest::Test
  REPORT = Shaka::Evaluation::SkillLibraryReport
  Status = Struct.new(:exitstatus) do
    def success? = exitstatus.zero?
  end

  def library(name, every_session, median, largest)
    { 'library' => name, 'commit' => 'abc', 'skills' => 2, 'commands' => 0, 'every_session' => every_session,
      'median_skill' => { 'name' => 'mid', 'text' => median },
      'largest_skill' => { 'name' => 'big', 'text' => largest } }
  end

  def libraries = [library('shaka', 'a b', 'c d e', 'c d e'), library('two', 'f', 'g h', 'i j k l')]

  def test_identical_texts_share_one_key
    keys = REPORT.keys(libraries)

    assert_equal ['shaka every_session', 'shaka median_skill', 'two every_session', 'two median_skill',
                  'two largest_skill'], keys.values
  end

  # Each text's count is its key's length, so a wrong lookup shows up as a wrong number.
  def counted(keys) = keys.values.to_h { |key| [key, key.length] }

  def test_rows_carry_words_and_each_clis_count_for_the_right_text
    keys = REPORT.keys(libraries)
    failed = { 'tokens' => 'UNKNOWN', 'reason' => 'claude timed out after 300s' }
    counts = [{ 'cli' => 'claude', 'texts' => counted(keys).merge('two largest_skill' => failed) },
              { 'cli' => 'codex', 'tokens' => 'UNKNOWN', 'reason' => 'codex is not installed' }]
    shaka, two = REPORT.rows(libraries, keys, counts)

    assert_equal [18, 'UNKNOWN'], shaka['largest_skill'].values_at('claude', 'codex')
    assert_equal failed, two['largest_skill']['claude']
    assert_equal [1, 17], two['every_session'].values_at('words', 'claude')
  end

  def test_other_libraries_have_no_codex_count
    keys = REPORT.keys(libraries)
    counts = [{ 'cli' => 'claude', 'texts' => counted(keys) }, { 'cli' => 'codex', 'texts' => counted(keys) }]
    two = REPORT.rows(libraries, keys, counts).last

    assert_equal([%w[words claude]] * 2, %w[every_session median_skill].map { |kind| two[kind].keys - ['name'] })
  end

  def test_words_only_rows_have_no_counts
    rows = REPORT.rows(libraries, REPORT.keys(libraries), nil)

    assert_equal({ 'words' => 2, 'name' => 'mid' }, rows.last['median_skill'])
  end

  # A fake CLI that reports one input token per word it is sent.
  def recording_runner(calls)
    lambda do |arguments, input|
      calls << [arguments.first, input]
      tokens = input.split.size
      usage = { 'input_tokens' => tokens, 'cache_creation_input_tokens' => 0, 'cache_read_input_tokens' => 0 }
      event = { 'type' => 'turn.completed', 'usage' => { 'input_tokens' => tokens } }
      [JSON.generate(arguments.first == 'claude' ? { 'usage' => usage } : event), Status.new(0)]
    end
  end

  def test_codex_is_sent_only_shakas_text
    calls = []
    keys = REPORT.keys(libraries)
    rows = REPORT.rows(libraries, keys, REPORT.count(keys, runner: recording_runner(calls)))
    codex = calls.filter_map { |cli, input| input if cli == 'codex' }
    prompt = InstructionTokens::PROMPT

    assert_equal [prompt, "a b\n\n#{prompt}", "c d e\n\n#{prompt}"], codex
    assert_equal([{ 'claude' => 3, 'codex' => 3 }, { 'claude' => 4 }],
                 rows.map { |row| row['largest_skill'].slice('claude', 'codex') })
  end
end
