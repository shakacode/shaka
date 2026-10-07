# frozen_string_literal: true

require_relative 'check'

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

      def initialize(root:, environment:, system:)
        @root = root
        @path = environment.fetch('PATH', '')
        @executable = system.executable
        @api_key_present = !environment.fetch('OPENROUTER_API_KEY', '').strip.empty?
      end

      def call(review)
        configured = review && Array(review['local_review_agents']).map do |entry|
          entry.values_at('provider', 'model_family').join('/').downcase
        end
        (SETUP.keys | Array(configured)).map { |identity| entry(identity, configured) }
      end

      private

      def entry(identity, configured)
        result = { identity:, provider: identity.split('/').first, configured: Array(configured).include?(identity) }
        result.merge(lookup(identity, role(identity, configured)))
      end

      def role(identity, configured)
        return 'configuration unavailable' unless configured

        configured.include?(identity) ? 'configured' : 'optional'
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
