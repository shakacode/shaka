# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative '../lib/instruction_tokens'

class InstructionTokensTest < Minitest::Test
  Status = Struct.new(:exitstatus) do
    def success? = exitstatus.zero?
  end
  OK = Status.new(0)
  # Each fake CLI spends a fixed prompt of its own, then one token per word it is sent.
  OWN_PROMPT = { 'claude' => 100, 'codex' => 40 }.freeze

  def counting_runner(calls = [])
    lambda do |arguments, input|
      calls << [arguments, input]
      tokens = OWN_PROMPT.fetch(arguments.first) + input.split.size
      [arguments.first == 'claude' ? claude_output(tokens) : codex_output(tokens), OK]
    end
  end

  def claude_output(tokens)
    JSON.generate('usage' => { 'input_tokens' => 2, 'cache_creation_input_tokens' => tokens - 5,
                               'cache_read_input_tokens' => 3, 'output_tokens' => 4 })
  end

  def codex_output(tokens)
    [{ 'type' => 'thread.started' }, { 'type' => 'turn.completed', 'usage' => { 'input_tokens' => tokens } }]
      .map { |event| JSON.generate(event) }.join("\n")
  end

  def values(rows, *keys) = rows.map { |row| row.values_at(*keys) }

  def test_counts_both_revisions_without_each_cli_prompt
    rows = InstructionTokens.compare(before: 'one two', after: 'one two three', runner: counting_runner)
    closing = InstructionTokens::PROMPT.split.size

    assert_equal([['claude', 'claude-opus-5-5', 100 + closing, 2, 3, 1],
                  ['codex', 'gpt-6.1-sol', 40 + closing, 2, 3, 1]],
                 values(rows, 'cli', 'model', 'cli_prompt', 'before', 'after', 'delta'))
  end

  def test_each_cli_runs_restricted_with_its_configured_model
    calls = []
    InstructionTokens.compare(before: nil, after: 'startup text', runner: counting_runner(calls))
    claude, codex = %w[claude codex].map { |name| calls.find { |arguments, _| arguments.first == name }.first }

    assert_includes claude.each_cons(2).to_a, ['--model', 'claude-opus-5-5']
    assert_includes claude, '--restricted'
    assert_includes codex.each_cons(2).to_a, ['-m', 'gpt-6.1-sol']
    assert_includes codex, '--ignore-user-config'
  end

  def test_the_text_goes_on_stdin_never_on_the_command_line
    calls = []
    InstructionTokens.compare(before: nil, after: 'startup text', runner: counting_runner(calls))
    claude = calls.select { |arguments, _| arguments.first == 'claude' }

    assert_equal [InstructionTokens::PROMPT, "startup text\n\n#{InstructionTokens::PROMPT}"], claude.map(&:last)
    assert(calls.none? { |arguments, _| arguments.any? { |argument| argument.include?('startup') } })
  end

  def test_unchanged_text_reuses_the_head_count
    calls = []
    rows = InstructionTokens.compare(before: 'same', after: 'same', runner: counting_runner(calls))

    assert_equal([[1, 1, 0]] * 2, values(rows, 'before', 'after', 'delta'))
    assert_equal 4, calls.size
  end

  def test_missing_baseline_counts_head_only
    rows = InstructionTokens.compare(before: nil, after: 'one', runner: counting_runner)

    assert_equal([[nil, 1, nil]] * 2, values(rows, 'before', 'after', 'delta'))
  end

  def test_a_missing_cli_is_unknown_after_one_attempt
    calls = []
    runner = lambda do |arguments, input|
      raise Errno::ENOENT, arguments.first if arguments.first == 'codex'

      counting_runner(calls).call(arguments, input)
    end
    rows = InstructionTokens.compare(before: 'a', after: 'b', runner:)

    assert_equal 0, rows.first['delta']
    assert_equal({ 'cli' => 'codex', 'model' => 'gpt-6.1-sol', 'tokens' => 'UNKNOWN',
                   'reason' => 'codex is not installed' }, rows.last)
  end

  def test_failed_runs_are_unknown_with_their_reason
    answers = { 'timeout' => [nil, nil], 'signed out' => ['', Status.new(1)], 'not json' => ['oops', OK],
                'no usage' => ['{"result":"ok"}', OK] }
    reasons = answers.values.map do |answer|
      InstructionTokens.compare(before: nil, after: 'a', runner: ->(*) { answer }).first['reason']
    end

    assert_equal ['claude timed out after 300s', 'claude did not finish successfully (exit 1)',
                  'claude reported no input token count', 'claude reported no input token count'], reasons
  end

  def test_a_failed_baseline_run_leaves_the_row_unknown
    runner = lambda do |arguments, input|
      input.start_with?('old') ? ['', Status.new(1)] : counting_runner.call(arguments, input)
    end
    rows = InstructionTokens.compare(before: 'old text', after: 'new text', runner:)

    assert_equal(['claude did not finish successfully (exit 1)', 'codex did not finish successfully (exit 1)'],
                 rows.map { |row| row['reason'] })
  end

  def test_any_unexpected_failure_is_unknown_rather_than_raised
    rows = InstructionTokens.compare(before: nil, after: 'a', runner: ->(*) { raise IOError, 'stream closed' })

    assert_equal(['claude failed: IOError', 'codex failed: IOError'], rows.map { |row| row['reason'] })
  end
end
