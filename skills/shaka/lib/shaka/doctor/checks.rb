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

      def initialize(root:, host:, environment:, system:)
        @root = root
        @host = host
        @environment = environment
        @system = system
      end

      def call = [github_cli, repository_access, repository_seam, alias_check, usage_source]

      private

      def alias_check = MachineAlias.new(@environment, host_name: @system.host_name).call

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

        permission(JSON.parse(out))
      rescue JSON::ParserError
        unreachable_repository('gh returned a response that is not repository JSON')
      end

      def unreachable_repository(reason)
        check('Repository access', 'failed', "no writable GitHub repository resolved here: #{reason}",
              guidance: 'Run doctor inside the checkout you publish from, and sign in with `gh auth login`.')
      end

      # Healthy has to name the repository and the permission it actually saw; a response
      # missing either one establishes nothing, however well-formed its JSON is.
      def permission(parsed)
        repository = parsed.is_a?(Hash) ? parsed['nameWithOwner'] : nil
        level = parsed.is_a?(Hash) ? parsed['viewerPermission'] : nil
        unless repository.is_a?(String) && !repository.empty? && level.is_a?(String)
          return unreachable_repository('gh did not report a repository and a permission')
        end
        return check('Repository access', 'healthy', "#{repository} is writable as #{level}") if WRITER.include?(level)

        check('Repository access', 'failed', "#{repository} is not writable (#{level})",
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

      # discover locates sources; it never opens them. Only a file this command can read is
      # evidence, so a session handle it cannot open is reported as located, not as ready.
      def usage_source
        return no_usage_source('the host is ambiguous') if @host.nil?

        located = @system.usage_source.call(@host)
        opened, unopened = located.partition { |entry| File.readable?(entry.to_s) }
        return check('Usage source', 'healthy', "#{opened.length} readable #{@host} source(s)") if openable?(located)

        no_usage_source(shortfall(located, unopened))
      rescue KeyError, SystemCallError => e
        no_usage_source(first_line(e.message))
      end

      def openable?(located) = !located.empty? && located.all? { |entry| File.readable?(entry.to_s) }

      def shortfall(located, unopened)
        return "no #{@host} session source" if located.empty?

        "#{unopened.length} of #{located.length} #{@host} sources cannot be opened here"
      end

      def no_usage_source(reason)
        check('Usage source', 'degraded', "#{reason}; usage may be incomplete",
              guidance: 'Pass `--host` to name the host, and `--file` to `shaka usage` when its ' \
                        'session source is not a file this command can read.')
      end

      # A command that cannot even launch is this check's answer, never an aborted report.
      def run(argv, chdir: nil)
        chdir ? Dir.chdir(chdir) { @system.runner.call(argv) } : @system.runner.call(argv)
      rescue SystemCallError => e
        ['', first_line(e.message), false]
      end
    end
  end
end
