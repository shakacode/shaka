# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative '../repository_config'
require_relative 'check'
require_relative 'machine_alias'

module Shaka
  class Doctor
    # Answers one question per check about this machine. Read-only: nothing here writes.
    class Checks
      include Check

      WRITER = %w[ADMIN MAINTAIN WRITE].freeze
      SEAM = '.agents/agent-workflow.yml'

      def initialize(root:, host:, environment:, runner:, usage_source:)
        @root = root
        @host = host
        @environment = environment
        @runner = runner
        @usage_source = usage_source
      end

      def call = [github_cli, repository_access, repository_seam, MachineAlias.new(@environment).call, usage_source]

      private

      def github_cli
        out, error, ok = run(%w[gh --version])
        return check('GitHub CLI', 'healthy', first_line(out)) if ok

        check('GitHub CLI', 'failed', "gh does not run: #{first_line(error)}",
              guidance: 'Install the GitHub CLI. Publication and merge need it.')
      end

      # This answers authentication and permission together, for the one repository that
      # matters, so a stale credential on an unrelated host cannot block a usable setup.
      # Any unresolved repository is a failure: doctor must never pass write access it did
      # not establish.
      def repository_access
        out, error, ok = run(['gh', 'repo', 'view', '--json', 'nameWithOwner,viewerPermission'], chdir: @root)
        return unreachable_repository(first_line(error)) unless ok

        parsed = JSON.parse(out)
        return unreachable_repository('gh returned a response that is not repository JSON') unless parsed.is_a?(Hash)

        permission(parsed)
      rescue JSON::ParserError
        unreachable_repository('gh returned a response that is not repository JSON')
      end

      def unreachable_repository(reason)
        check('Repository access', 'failed', "no writable GitHub repository resolved here: #{reason}",
              guidance: 'Run doctor inside the checkout you publish from, and sign in with `gh auth login`.')
      end

      def permission(parsed)
        level = parsed['viewerPermission']
        repository = parsed['nameWithOwner']
        return check('Repository access', 'healthy', "#{repository} is writable as #{level}") if WRITER.include?(level)

        check('Repository access', 'failed', "#{repository} is not writable (#{level || 'no permission'})",
              guidance: 'Use an account with write access, or re-authenticate with `gh auth login`.')
      end

      # This reads the working tree, so it answers whether this checkout's contract is usable.
      # It deliberately does not restate the seam's commands or merge preference: doctor takes
      # no authority from the seam, and the workflow revalidates policy from a trusted ref.
      def repository_seam
        return missing_seam unless File.exist?(File.join(@root, SEAM))

        RepositoryConfig.load(root: @root)
        check('Repository seam', 'healthy', "#{SEAM} loads and validates in this working tree")
      rescue Shaka::Error, SystemCallError => e
        check('Repository seam', 'failed', "#{SEAM} is not usable: #{first_line(e.message)}",
              guidance: 'Repair the contract, or let `shaka seam init` rewrite a valid one.')
      end

      def missing_seam
        check('Repository seam', 'failed', "this root has no #{SEAM}",
              guidance: 'Run `shaka seam init` here, or point `--root` at the repository you meant.')
      end

      # discover locates sources; it does not open them, so unreadable ones are reported here.
      def usage_source
        located = @usage_source.call(@host)
        return no_usage_source("no #{@host} session source") if located.empty?
        return no_usage_source(unreadable_of(located)) if unreadable(located).any?

        check('Usage source', 'healthy', "#{located.length} readable #{@host} source(s)")
      rescue KeyError, SystemCallError => e
        no_usage_source(first_line(e.message))
      end

      def unreadable(located) = located.select { |entry| entry.start_with?('/') && !File.readable?(entry) }

      def unreadable_of(located) = "#{unreadable(located).length} of #{located.length} sources cannot be read"

      def no_usage_source(reason)
        check('Usage source', 'degraded', "#{reason}; usage tables will be empty",
              guidance: "Run the task from #{@host} so its session transcript exists, " \
                        'or pass `--file` to `shaka usage`.')
      end

      # A command that cannot even launch is this check's answer, never an aborted report.
      def run(argv, chdir: nil)
        chdir ? Dir.chdir(chdir) { @runner.call(argv) } : @runner.call(argv)
      rescue SystemCallError => e
        ['', first_line(e.message), false]
      end
    end
  end
end
