# frozen_string_literal: true

require_relative 'check'
require_relative '../configuration'

module Shaka
  class Doctor
    # Presence on PATH is evidence of an installed CLI, not of authentication or quota.
    class ReviewerClis
      include Check

      COMMANDS = { 'openai/codex' => 'codex', 'anthropic/claude' => 'claude', 'xai/grok' => 'grok' }.freeze
      PROVIDERS = { 'codex' => 'openai', 'claude-code' => 'anthropic' }.freeze
      GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#add-a-second-reviewer'

      def initialize(root:, host:, environment:, system:)
        @root = root
        @provider = PROVIDERS[host]
        @path = environment.fetch('PATH', '')
        @executable = system.executable
      end

      def call(seam)
        return check('Reviewer CLIs', 'degraded', 'not checked: repository seam is not healthy') unless
          seam[:status] == 'healthy'

        report(Configuration.worktree(root: @root).review)
      rescue Shaka::Error, SystemCallError => e
        check('Reviewer CLIs', 'degraded', "not checked: #{first_line(e.message)}", guidance: GUIDE)
      end

      private

      def report(review)
        entries = Array(review['local_review_agents']).map { |entry| availability(entry) }
        warnings = warnings(entries, review.fetch('local_review_count', 1))
        summary = entries.map { |entry| entry.fetch(:summary) } + warnings
        summary << 'No local reviewers configured; fresh host review remains available.' if entries.empty?
        check('Reviewer CLIs', warnings.empty? ? 'healthy' : 'degraded', summary.join(' '),
              guidance: warnings.empty? ? nil : "Add a second reviewer: #{GUIDE}")
      end

      def availability(entry)
        identity = entry.values_at('provider', 'model_family').join('/').downcase
        command = COMMANDS[identity]
        unless command
          return { provider: entry.fetch('provider').downcase, installed: false,
                   summary: "#{identity}: no supported CLI adapter." }
        end

        installed = @executable.call(command, @path, @root)
        state = installed ? 'on PATH' : 'missing from PATH'
        { provider: entry.fetch('provider').downcase, installed:, summary: "#{identity}: #{command} #{state}." }
      end

      def warnings(entries, count)
        providers = entries.select { |entry| entry[:installed] }.map { |entry| entry[:provider] }.uniq
        lines = []
        lines << "#{providers.size} provider#{'s' unless providers.one?} available; #{count} reviewers requested." if
          providers.size < count
        if providers == [@provider]
          lines << "Only the current host's provider (#{@provider}) is available; no different-provider CLI was found."
        end
        lines
      end
    end
  end
end
