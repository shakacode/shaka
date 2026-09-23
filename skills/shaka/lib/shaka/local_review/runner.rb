# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tempfile'
require_relative '../reviewer_selection'
require_relative 'cli'

module Shaka
  # Checks the exact revision, launches a reviewer, and validates its report.
  class LocalReviewRunner
    def initialize(options) = @options = options

    def run
      validate!
      prompt = review_prompt
      report = Tempfile.create(['shaka-review-', '.md'])
      report.close
      result = LocalReviewCli.new(@options, root:, report: report.path).run(prompt)
      result || validate_report(report.path)
    rescue Shaka::Error, SystemCallError => e
      { 'status' => 'not_completed', 'head' => head, 'reviewer' => @options[:reviewer],
        'attempted' => false, 'failure_stage' => 'setup_failure', 'reason' => e.message }
    end

    private

    def validate!
      %i[base head].each do |key|
        raise Shaka::Error, "--#{key} must be a full commit SHA" unless @options[key].to_s.match?(LocalReview::SHA)
      end
      validate_reviewer!
      validate_checkout!
    end

    def validate_reviewer!
      @options[:reviewer] = ReviewerSelection.parse(@options.fetch(:reviewer)).values.join('/')
      unless %w[openai/codex anthropic/claude xai/grok].include?(reviewer)
        raise Shaka::Error, 'Unsupported local reviewer'
      end
      raise Shaka::Error, '--model is required for xai/grok' if reviewer == 'xai/grok' && @options[:model].to_s.empty?
    end

    def validate_checkout!
      actual = capture('git', '-C', root, 'rev-parse', 'HEAD').strip
      raise Shaka::Error, "Checkout HEAD is #{actual}, not #{head}" unless actual == head
    end

    def validate_report(path)
      text = File.read(path, encoding: 'UTF-8')
      return incomplete('Reviewer returned no matching review attestation', path) unless
        LocalReviewAttestation.valid?(text, head: head, reviewer: reviewer)

      { 'status' => 'completed', 'head' => head, 'reviewer' => reviewer,
        'report' => path, 'usage' => @options[:usage] }.compact
    end

    def review_prompt
      script = File.expand_path('../../../scripts/shaka', __dir__)
      output = capture(RbConfig.ruby, script, 'review-prompt', '--head', head,
                       '--base', @options[:base], '--reviewer', reviewer, '--effort', effort)
      diff = capture('git', '-C', root, 'diff', '--no-ext-diff', '--no-textconv', "#{@options[:base]}...#{head}", '--')
      "#{output}\n\n--- BEGIN DIFF DATA ---\n#{diff}\n--- END DIFF DATA ---\n"
    end

    def capture(*arguments)
      stdout, stderr, status = Open3.capture3(*arguments)
      raise Shaka::Error, "#{arguments.first} failed: #{stderr.strip}" unless status.success?

      stdout
    end

    def incomplete(reason, report)
      { 'status' => 'not_completed', 'head' => head, 'reviewer' => reviewer,
        'attempted' => true, 'failure_stage' => 'report_validation', 'reason' => reason, 'report' => report }
    end

    def root = @root ||= File.realpath(@options.fetch(:root, Dir.pwd))

    def head = @options[:head]

    def reviewer = @options[:reviewer]

    def effort = @options.fetch(:effort, 'UNKNOWN')
  end
end
