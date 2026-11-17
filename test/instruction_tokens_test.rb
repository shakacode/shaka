# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative '../lib/instruction_tokens'

# Fake CLIs: each spends a fixed prompt of its own, then one token per word it is sent.
module InstructionTokensFakes
  Status = Struct.new(:exitstatus) do
    def success? = exitstatus.zero?
  end
  OK = Status.new(0)
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
end

class InstructionTokensTest < Minitest::Test
  include InstructionTokensFakes

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
    claude, codex = %w[claude codex].map do |name|
      calls.find { |arguments, _| arguments.first == name }.first.each_cons(2).to_a
    end

    assert_includes claude, ['--model', 'claude-opus-5-5']
    assert_includes claude, ['--tools', '']
    assert_includes codex, ['-m', 'gpt-6.1-sol']
    assert_includes codex, ['--ignore-rules', '--ignore-user-config']
  end

  def test_codex_runs_without_its_shell_tools
    arguments = InstructionTokens::CLIS.fetch('codex').arguments.call('model', 'low').each_cons(2).to_a

    assert_includes arguments, ['--disable', 'shell_tool']
    assert_includes arguments, ['--disable', 'unified_exec']
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

  # The text is agent instructions; a run that acts on them reports usage for several model requests.
  def test_a_run_that_used_a_tool_counts_nothing
    runner = lambda do |arguments, _input|
      next ['{"num_turns":2,"usage":{}}', OK] if arguments.first == 'claude'

      tool = { 'type' => 'item.completed', 'item' => { 'type' => 'command_execution' } }
      [[codex_output(99), JSON.generate(tool)].join("\n"), OK]
    end
    rows = InstructionTokens.compare(before: nil, after: 'Run pwd.', runner:)

    assert_equal(["claude used a tool, so its count is not the text's alone",
                  "codex used a tool, so its count is not the text's alone"], rows.map { |row| row['reason'] })
  end

  # Without its shell tools Codex can still answer twice, and each answer is another model request.
  def test_a_codex_run_with_two_answers_counts_nothing
    answer = { 'type' => 'item.completed', 'item' => { 'type' => 'agent_message' } }
    runner = lambda do |arguments, input|
      next counting_runner.call(arguments, input) if arguments.first == 'claude'

      [[codex_output(99), JSON.generate(answer), JSON.generate(answer)].join("\n"), OK]
    end
    rows = InstructionTokens.compare(before: nil, after: 'Read a file.', runner:)

    assert_equal "codex used a tool, so its count is not the text's alone", rows.last['reason']
  end

  def test_a_failed_baseline_run_keeps_the_head_count
    runner = lambda do |arguments, input|
      input.start_with?('old') ? ['', Status.new(1)] : counting_runner.call(arguments, input)
    end
    rows = InstructionTokens.compare(before: 'old text', after: 'new text', runner:)

    assert_equal(%w[claude codex].map do |name|
      [nil, 2, nil, "baseline not counted: #{name} did not finish successfully (exit 1)"]
    end, values(rows, 'before', 'after', 'delta', 'reason'))
  end

  def test_any_unexpected_failure_is_unknown_rather_than_raised
    rows = InstructionTokens.compare(before: nil, after: 'a', runner: ->(*) { raise IOError, 'stream closed' })

    assert_equal(['claude failed: IOError', 'codex failed: IOError'], rows.map { |row| row['reason'] })
  end
end

class InstructionTokensCountEachTest < Minitest::Test
  include InstructionTokensFakes

  def test_count_each_measures_each_cli_prompt_once_for_every_text
    calls = []
    rows = InstructionTokens.count_each({ 'short' => 'one', 'long' => 'one two three' }, runner: counting_runner(calls))

    assert_equal([{ 'short' => 1, 'long' => 3 }] * 2, rows.map { |row| row['texts'] })
    assert_equal 6, calls.size
  end

  def test_count_each_keeps_other_counts_when_one_text_fails
    runner = lambda do |arguments, input|
      input.start_with?('bad') ? ['', Status.new(2)] : counting_runner.call(arguments, input)
    end
    rows = InstructionTokens.count_each({ 'good' => 'one two', 'bad' => 'bad text' }, runner:)

    assert_equal 2, rows.first['texts']['good']
    assert_equal({ 'tokens' => 'UNKNOWN', 'reason' => 'claude did not finish successfully (exit 2)' },
                 rows.first['texts']['bad'])
  end

  def test_count_each_is_unknown_when_the_cli_prompt_cannot_be_measured
    rows = InstructionTokens.count_each({ 'a' => 'one' }, runner: ->(*) { raise Errno::ENOENT })

    assert_equal(['claude is not installed', 'codex is not installed'], rows.map { |row| row['reason'] })
  end
end
