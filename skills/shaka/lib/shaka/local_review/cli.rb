# frozen_string_literal: true

require 'json'
require 'open3'
require 'tempfile'
require_relative 'executable'

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
      return missing('codex') unless LocalReviewExecutable.available?('codex')

      stdout, stderr, status = Open3.capture3('codex', 'exec', '-s', 'read-only', '--ignore-rules',
                                              '--ignore-user-config', '--skip-git-repo-check', '-o', @report, '-',
                                              stdin_data: prompt, chdir: @root)
      return failure("codex exec exited #{status.exitstatus}", stderr) unless status.success?

      invalid('codex exec returned no review', stdout) unless File.size?(@report)
    end

    def claude(prompt)
      return missing('claude') unless LocalReviewExecutable.available?('claude')

      output, stderr, status = claude_process(prompt)
      return failure("claude -p exited #{status.exitstatus}", [stderr, output].join("\n")) unless status.success?

      claude_result(output)
    rescue JSON::ParserError
      invalid('claude -p returned malformed JSON', output)
    end

    def claude_process(prompt)
      args = ['claude', '-p', '--permission-mode', 'plan', '--permission-prompts', 'none', '--restricted',
              '--safe-mode', '--strict-mcp-config']
      args.push('--effort', effort) if effort
      args.push('--output-format', 'json', '-')
      output, stderr, status = Open3.capture3(*args, stdin_data: prompt, chdir: @root)
      [output, stderr, status]
    end

    def claude_result(output)
      result = JSON.parse(output)
      return invalid('claude -p returned non-object JSON', output) unless result.is_a?(Hash)

      return failure('claude -p reported an error', output) if result['is_error']
      return invalid('claude -p returned no review', output) unless valid_claude_result?(result)

      @options[:usage] = save_usage(output)
      File.write(@report, result.fetch('result'))
      nil
    end

    def valid_claude_result?(result) = result['result'].is_a?(String) && !result['result'].strip.empty?

    def grok(prompt)
      return missing('grok') unless LocalReviewExecutable.available?('grok')

      file = prompt_file(prompt)
      output, stderr, status = grok_process(file.path)
      return failure("grok exited #{status.exitstatus}", stderr) unless status.success?

      File.write(@report, output)
      invalid('grok returned no review') unless File.size?(@report)
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
      args = ['grok', '--prompt-file', prompt_path, '-m', @options[:model]]
      args.push('--reasoning-effort', effort) if effort
      args.push('--output-format', 'plain', '--permission-mode', 'plan', '--disable-web-search', '--no-subagents')
      output, stderr, status = Open3.capture3(*args, chdir: @root)
      [output, stderr, status]
    end

    def save_usage(output)
      file = Tempfile.create(['shaka-review-usage-', '.json'])
      file.write(output)
      file.close
      file.path
    end

    def missing(name) = outcome("#{name} is not on PATH", 'executable_missing', false)

    def failure(reason, diagnostic = nil)
      outcome(reason, 'cli_failure', true).merge('diagnostic_path' => save_diagnostic(diagnostic))
    end

    def invalid(reason, diagnostic = nil)
      outcome(reason, 'report_validation', true).merge('diagnostic_path' => save_diagnostic(diagnostic)).compact
    end

    def outcome(reason, stage, attempted)
      File.unlink(@report) if stage != 'report_validation' && File.exist?(@report)
      { 'status' => 'not_completed', 'head' => @options[:head], 'reviewer' => @options[:reviewer],
        'attempted' => attempted, 'failure_stage' => stage, 'reason' => reason,
        'report' => stage == 'report_validation' && File.size?(@report) ? @report : nil,
        'skip_evidence' => { 'executable_missing' => 'confirmed',
                             'cli_failure' => 'requires_cause_review' }.fetch(stage, 'not_eligible'),
        'usage' => @options[:usage] }.compact
    end

    def save_diagnostic(text)
      return nil if text.to_s.empty?

      file = Tempfile.create(['shaka-review-diagnostic-', '.txt'])
      file.write(text)
      file.close
      file.path
    end

    def effort = @options[:effort]
  end
end
