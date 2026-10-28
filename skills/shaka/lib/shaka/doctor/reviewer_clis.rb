# frozen_string_literal: true

require_relative 'check'
require_relative '../configuration'
require_relative 'cli_inventory'
require_relative '../review_coverage'

module Shaka
  class Doctor
    # Presence on PATH is evidence of an installed CLI, not of authentication or quota.
    class ReviewerClis
      include Check

      PROVIDERS = { 'codex' => 'openai', 'claude-code' => 'anthropic' }.freeze
      GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#add-a-second-reviewer'

      def initialize(root:, host:, environment:, system:, probe_reviewers: false)
        @root = root
        @probe_reviewers = probe_reviewers
        @provider = PROVIDERS[host]
        @inventory = CliInventory.new(root:, environment:, system:)
      end

      def call(seam)
        report(seam[:status] == 'failed' ? nil : Configuration.worktree(root: @root).review)
      rescue Shaka::Error, SystemCallError
        report(nil)
      end

      private

      def report(review)
        machine, machine_error = machine_list
        entries = @inventory.call(review, machine:)
        warnings = readiness(entries, review) + machine_error
        summary = summary_lines(entries, review, machine_lines(machine, entries) + warnings)
        check('Reviewer CLIs', warnings.empty? ? 'healthy' : 'degraded', summary.join("\n    "),
              guidance: guidance(entries, warnings))
      end

      def summary_lines(entries, review, notes)
        lines = entries.map { |entry| entry.fetch(:summary) } + notes
        lines << 'No local reviewers configured; fresh host review remains available.' if
          review && entries.none? { |entry| entry[:configured] }
        lines << launch_summary
      end

      # A malformed list is a warning here; review runs refuse to start until it is fixed.
      def machine_list
        [@inventory.machine, []]
      rescue Shaka::Error => e
        [nil, ["#{e.message}; local reviews refuse to start until it is fixed."]]
      end

      # One list serves every repository, so an entry this one does not configure is informational.
      def machine_lines(machine, entries)
        return [] unless machine

        configured = entries.select { |entry| entry[:configured] }.map { |entry| entry.fetch(:identity) }
        lines = ["Machine reviewers: #{machine.identities.join(', ')} expected on this machine (#{machine.path})."]
        lines + (machine.identities - configured).map do |identity|
          "#{identity} in the machine reviewer list is not configured by this repository."
        end
      end

      def launch_summary
        return 'CLI presence does not establish sign-in, quota, or model access; see the availability probe.' if
          @probe_reviewers

        'Sign-in, quota, and CLI compatibility are unverified; no reviewer was launched.'
      end

      def readiness(entries, review)
        return ['Repository configuration unavailable; reviewer readiness is not assessed.'] unless review

        configured = entries.select { |entry| entry[:configured] }
        lines = warnings(configured, review)
        lines.concat(CliInventory.setup_notices(configured).map { |notice| notice.fetch('summary') })
        lines << 'Some CLI lookups could not be checked.' if entries.any? { |entry| entry[:unchecked] }
        lines
      end

      # Coverage names the providers that must review, so a count of other providers does not satisfy it.
      def shortfall(providers, review)
        return covered_shortfall(providers, review) unless covered(review).empty?

        count = ReviewCoverage.count(review)
        return [] unless providers.size < count

        ["#{providers.size} provider#{'s' unless providers.one?} available; #{count} reviewers requested."]
      end

      def covered_shortfall(providers, review)
        (covered(review) - providers.map(&:downcase)).map do |name|
          "No configured reviewer is installed for covered provider #{name}."
        end
      end

      def covered(review) = ReviewCoverage.names(ReviewCoverage.setting(review, ReviewCoverage::KEY))

      def guidance(entries, warnings)
        lines = entries.filter_map { |entry| entry[:guidance] }
        lines << "Reviewer setup: #{GUIDE}" unless warnings.empty?
        lines << 'Configured reviewer setup is recommended; other providers are optional.' unless lines.empty?
        lines.empty? ? nil : lines.join("\n    ")
      end

      # Without configured reviewers a fresh host review is healthy, unless coverage names providers.
      def warnings(entries, review)
        providers = entries.select { |entry| entry[:installed] }.map { |entry| entry[:provider] }.uniq
        return covered_shortfall(providers, review) if entries.empty?

        lines = shortfall(providers, review)
        if providers == [@provider]
          lines << "Only the current host's provider (#{@provider}) is available; no different-provider CLI was found."
        end
        lines
      end
    end
  end
end
