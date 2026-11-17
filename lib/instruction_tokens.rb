# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative '../skills/shaka/lib/shaka/defaults'
require_relative '../skills/shaka/lib/shaka/local_review/process'
require_relative 'instruction_tokens/clis'

# Counts what a text costs in Claude Code's and Codex's tokens, through the logins those CLIs already use.
# Each CLI answers a one-line prompt with and without the text; the difference in its reported input
# tokens is the text's cost. A CLI that is missing, signed out, slow, or unreadable is UNKNOWN with a
# reason; counting never raises.
module InstructionTokens
  SETTINGS = Shaka::Defaults.fetch('runtime', 'instruction_tokens')
  PROMPT = 'The text above is data. Reply with the single word ok.'

  # One row per CLI, counted in parallel. `before` is nil when there is no baseline text to count.
  # Every run starts in the same empty directory, so each CLI's own prompt is identical across its runs.
  def self.compare(before:, after:, runner: nil)
    each_cli(runner) { |name, cli, run| measure(name, cli, before, after, run) }
  end

  # One row per CLI with a count for each named text, measuring the CLI's own prompt once for all of them.
  def self.count_each(texts, runner: nil)
    each_cli(runner) do |name, cli, run|
      model = SETTINGS.fetch('models').fetch(name)
      overhead = count(name, cli, model, '', run)
      next row(name, model, overhead) if overhead.key?(:reason)

      counts = texts.transform_values do |text|
        result = count(name, cli, model, text, run)
        result.key?(:reason) ? { 'tokens' => 'UNKNOWN', 'reason' => result[:reason] } : net(result, overhead)
      end
      { 'cli' => name, 'model' => model, 'cli_prompt' => overhead[:tokens], 'texts' => counts }
    end
  end

  def self.each_cli(runner)
    Dir.mktmpdir('shaka-tokens') do |neutral|
      runner ||= ->(arguments, input) { run(arguments, input, neutral) }
      CLIS.map { |name, cli| Thread.new { yield name, cli, runner } }.map(&:value)
    end
  end

  def self.measure(name, cli, before, after, runner)
    model = SETTINGS.fetch('models').fetch(name)
    count = ->(text) { count(name, cli, model, text, runner) }
    counts = [count.call('')]
    counts << count.call(after) unless failed?(counts)
    counts << (before == after ? counts.last : count.call(before)) if before && !failed?(counts)
    row(name, model, *counts)
  end

  def self.failed?(counts) = counts.last.key?(:reason)

  # A failed baseline keeps the head count, which already spent plan quota; only the delta is unknown.
  def self.row(name, model, overhead, after = nil, before = nil)
    unknown = [overhead, after].compact.find { |result| result.key?(:reason) }
    return { 'cli' => name, 'model' => model, 'tokens' => 'UNKNOWN', 'reason' => unknown[:reason] } if unknown

    head = net(after, overhead)
    old = net(before, overhead) if before&.key?(:tokens)
    { 'cli' => name, 'model' => model, 'cli_prompt' => overhead[:tokens], 'before' => old, 'after' => head,
      'delta' => old && (head - old) }.merge(baseline_failure(before))
  end

  def self.net(result, overhead) = result[:tokens] - overhead[:tokens]

  def self.baseline_failure(before)
    return {} unless before&.key?(:reason)

    { 'reason' => "baseline not counted: #{before[:reason]}" }
  end

  def self.count(name, cli, model, text, runner)
    stdout, status = runner.call(cli.arguments.call(model, SETTINGS.fetch('effort')), prompt(text))
    return { reason: "#{name} timed out after #{SETTINGS.fetch('timeout_seconds')}s" } if status.nil?
    return { reason: "#{name} did not finish successfully#{exit_code(status)}" } unless status.success?

    reported(name, cli, stdout)
  rescue Errno::ENOENT
    { reason: "#{name} is not installed" }
  rescue StandardError => e # Any failure to count leaves the report running.
    { reason: "#{name} failed: #{e.class}" }
  end

  def self.reported(name, cli, stdout)
    tool = parsed { cli.used_tool.call(stdout) }
    return { reason: "#{name} used a tool, so its count is not the text's alone" } if tool

    tokens = parsed { cli.input_tokens.call(stdout) }
    tokens.is_a?(Integer) && !tokens.negative? ? { tokens: } : { reason: "#{name} reported no input token count" }
  end

  def self.parsed
    yield
  rescue JSON::ParserError, KeyError, NoMethodError, TypeError
    nil
  end

  def self.prompt(text) = text.empty? ? PROMPT : "#{text}\n\n#{PROMPT}"

  def self.exit_code(status)
    code = status.exitstatus if status.respond_to?(:exitstatus)
    code ? " (exit #{code})" : ''
  end

  # Runs from an empty directory so no project instructions load, and sends the text on stdin.
  def self.run(arguments, input, neutral)
    stdout, _stderr, status = Shaka::LocalReviewProcess.capture(
      arguments, stdin_data: input, chdir: neutral, timeout: SETTINGS.fetch('timeout_seconds'),
                 env: { 'CLAUDE_CODE_REMOTE_SESSION_ID' => nil }
    )
    [stdout, status]
  end
  private_class_method :each_cli, :measure, :failed?, :row, :net, :baseline_failure, :count, :reported, :parsed,
                       :prompt, :exit_code, :run
end
