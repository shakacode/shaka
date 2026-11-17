# frozen_string_literal: true

require 'json'

# How each CLI runs for a token count, and how its output reports input tokens and tool use.
module InstructionTokens
  Cli = Data.define(:arguments, :input_tokens, :used_tool)
  CODEX_ANSWERS = %w[agent_message reasoning].freeze # Any other Codex item is a tool call.

  # The startup text is agent instructions, so a CLI might act on them. A tool call adds model requests
  # to the reported usage, so Claude runs with no tools and a Codex run that calls one counts nothing.
  # As for Shaka's local reviewers, no rules, skills, hooks, or MCP servers load.
  CLIS = {
    'claude' => Cli.new(
      arguments: lambda do |model, effort|
        %w[claude -p --permission-mode plan --permission-prompts none --restricted --safe-mode
           --strict-mcp-config --tools] + ['', '--model', model, '--effort', effort, '--output-format', 'json', '-']
      end,
      input_tokens: lambda do |stdout|
        usage = JSON.parse(stdout)['usage']
        %w[input_tokens cache_creation_input_tokens cache_read_input_tokens].sum { |key| usage.fetch(key) }
      end,
      used_tool: ->(stdout) { JSON.parse(stdout).fetch('num_turns', 1) > 1 }
    ),
    'codex' => Cli.new(
      arguments: lambda do |model, effort|
        %w[codex exec -s read-only --ignore-rules --ignore-user-config -c skills.include_instructions=false
           --skip-git-repo-check --json] + ['-m', model, '-c', %(model_reasoning_effort="#{effort}"), '-']
      end,
      # Codex reports cached input inside input_tokens.
      input_tokens: lambda do |stdout|
        events(stdout).find { |event| event['type'] == 'turn.completed' }&.dig('usage', 'input_tokens')
      end,
      used_tool: lambda do |stdout|
        events(stdout).any? { |event| event['item'] && !CODEX_ANSWERS.include?(event['item']['type']) }
      end
    )
  }.freeze

  def self.events(stdout) = stdout.lines.filter_map { |line| JSON.parse(line) if line.start_with?('{') }
  private_class_method :events
end
