# frozen_string_literal: true

require 'json'
require 'open3'
require 'tempfile'

module Shaka
  # The only path that may claim a local review process was actually launched.
  class LocalReviewCli
    def initialize(options, root:, report:)
      @options = options
      @root = root
      @report = report
    end

    def run(prompt)
      case @options.fetch(:reviewer)
      when 'openai/codex' then codex(prompt)
      when 'anthropic/claude' then claude(prompt)
      when 'xai/grok' then grok(prompt)
      end
    end

    private

    def codex(prompt)
      _stdout, _stderr, status = Open3.capture3('codex', 'exec', '-s', 'read-only', '--ignore-rules',
                                                '--ignore-user-config', '-o', @report, '-',
                                                stdin_data: prompt, chdir: @root)
      return failure("codex exec exited #{status.exitstatus}") unless status.success?

      invalid('codex exec returned no review') unless File.size?(@report)
    rescue Errno::ENOENT
      missing('codex')
    end

    def claude(prompt)
      output, status = claude_process(prompt)
      @options[:usage] = save_usage(output)
      return failure("claude -p exited #{status.exitstatus}") unless status.success?

      claude_result(output)
    rescue Errno::ENOENT
      missing('claude')
    rescue JSON::ParserError
      invalid('claude -p returned malformed JSON')
    end

    def claude_process(prompt)
      args = ['claude', '-p', '--permission-mode', 'plan', '--permission-prompts', 'none', '--restricted',
              '--safe-mode', '--strict-mcp-config', '--effort', effort, '--output-format', 'json', '-']
      output, _stderr, status = Open3.capture3(*args, stdin_data: prompt, chdir: @root)
      [output, status]
    end

    def claude_result(output)
      result = JSON.parse(output)
      return failure('claude -p reported an error') if result['is_error']
      return invalid('claude -p returned no review') unless valid_claude_result?(result)

      File.write(@report, result.fetch('result'))
      nil
    end

    def valid_claude_result?(result)
      result['result'].is_a?(String) && !result['result'].strip.empty?
    end

    def grok(prompt)
      file = prompt_file(prompt)
      output, status = grok_process(file.path)
      return failure("grok exited #{status.exitstatus}") unless status.success?

      File.write(@report, output)
      invalid('grok returned no review') unless File.size?(@report)
    rescue Errno::ENOENT
      missing('grok')
    ensure
      File.unlink(file.path) if file && File.exist?(file.path)
    end

    def prompt_file(prompt)
      file = Tempfile.create('shaka-review-prompt-')
      file.write(prompt)
      file.close
      file
    end

    def grok_process(prompt_path)
      output, _stderr, status = Open3.capture3('grok', '--prompt-file', prompt_path, '-m', @options[:model],
                                               '--reasoning-effort', effort, '--output-format', 'plain',
                                               '--permission-mode', 'plan', '--disable-web-search', '--no-subagents',
                                               chdir: @root)
      [output, status]
    end

    def save_usage(output)
      file = Tempfile.create(['shaka-review-usage-', '.json'])
      file.write(output)
      file.close
      file.path
    end

    def missing(name) = outcome("#{name} is not on PATH", 'executable_missing', false)

    def failure(reason) = outcome(reason, 'cli_failure', true)

    def invalid(reason) = outcome(reason, 'report_validation', true)

    def outcome(reason, stage, attempted)
      { 'status' => 'not_completed', 'head' => @options[:head], 'reviewer' => @options[:reviewer],
        'attempted' => attempted, 'failure_stage' => stage, 'reason' => reason, 'report' => @report,
        'usage' => @options[:usage] }.compact
    end

    def effort = @options.fetch(:effort, 'UNKNOWN')
  end
end
