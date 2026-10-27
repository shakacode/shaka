# frozen_string_literal: true

require_relative 'check'
require_relative '../local_review/path_guard'
require_relative '../reviewer_selection'
require_relative '../review_coverage'

module Shaka
  class Doctor
    # Look up supported reviewers without launching them, even before repository setup.
    class CliInventory
      include Check

      SETUP = {
        'openai/codex' => ['codex', 'https://github.com/openai/codex', 'run `codex login`'],
        'anthropic/claude' => ['claude', 'https://code.claude.com/docs/en/setup', 'run `claude` and sign in'],
        'xai/grok' => ['grok', 'https://docs.x.ai/build/overview', 'run `grok` and sign in']
      }.freeze

      def initialize(root:, environment:, system: nil)
        @root = root
        @path = environment.fetch('PATH', '')
        @executable = system ? system.executable : method(:executable)
        @api_key_present = !environment.fetch('OPENROUTER_API_KEY', '').b.strip.empty?
      end

      def call(review)
        configured = review && Array(review['local_review_agents']).map do |entry|
          entry.values_at('provider', 'model_family').join('/').downcase
        end
        covered = review ? ReviewCoverage.names(ReviewCoverage.setting(review, ReviewCoverage::KEY)) : []
        (SETUP.keys | Array(configured)).map { |identity| entry(identity, configured, covered) }
      end

      # Selection never picks an optional entry on its own, so its missing setup needs no notice.
      def self.setup_notices(entries)
        entries.select { |entry| entry[:configured] && !entry[:optional] && !entry[:installed] }.map do |entry|
          { 'reviewer' => entry.fetch(:identity),
            'summary' => "This repository configures #{entry.fetch(:identity)} reviews, but local setup is incomplete.",
            'guidance' => entry[:guidance] || 'Ask the repository maintainer which supported reviewer to configure.' }
        end
      end

      # Configured reviewers this machine definitely lacks. A lookup that could not be checked is
      # left to the review run, which reports its own failure.
      def self.not_set_up(entries)
        entries.select { |entry| entry[:configured] && !entry[:installed] && !entry[:unchecked] }.map do |entry|
          ReviewerSelection.parse(entry.fetch(:identity))
        end
      end

      private

      def executable(name, path, root)
        LocalReviewPathGuard.safe_executable(path, name, root)
      end

      # With provider_coverage, a configured entry from a provider it does not name runs only when a
      # task names it.
      def entry(identity, configured, covered)
        provider = identity.split('/').first
        listed = Array(configured).include?(identity)
        result = { identity:, provider:, configured: listed,
                   optional: listed && !covered.empty? && !covered.include?(provider) }
        result.merge(lookup(identity, role(result, configured)))
      end

      def role(entry, configured)
        return 'configuration unavailable' unless configured
        return 'optional' unless entry[:configured]

        entry[:optional] ? 'optional: runs only when a task names it' : 'configured'
      end

      def lookup(identity, role)
        return openrouter(role) if identity == 'deepseek/openrouter'
        return { installed: false, summary: "#{identity}: no supported CLI adapter." } unless SETUP.key?(identity)

        cli_lookup(identity, role)
      end

      def cli_lookup(identity, role)
        command, url, sign_in = SETUP.fetch(identity)
        path = @executable.call(command, @path, @root)
        state = path ? "on PATH#{" at #{path}" if path.is_a?(String)}" : 'missing from PATH'
        { installed: !path.nil? && path != false, summary: "#{identity}: #{command} #{state} (#{role}).",
          guidance: path ? nil : "Install #{command}: #{url}; then #{sign_in}." }
      rescue Shaka::Error, SystemCallError => e
        { installed: false, summary: "#{identity}: #{command} not checked: #{first_line(e.message)}",
          guidance: "Repair the #{command} PATH entry, then rerun `shaka doctor`.", unchecked: true }
      end

      def openrouter(role)
        state = @api_key_present ? 'present; API access unverified' : 'missing'
        { installed: @api_key_present, summary: "deepseek/openrouter: OPENROUTER_API_KEY #{state} (#{role}).",
          guidance: (@api_key_present ? nil : 'Set OPENROUTER_API_KEY for the opt-in DeepSeek API reviewer.') }
      end
    end
  end
end
