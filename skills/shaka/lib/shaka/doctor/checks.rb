# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative '../provenance'
require_relative '../repository_config'

module Shaka
  class Doctor
    # Answers one question per check about this machine. Read-only: nothing here writes.
    class Checks
      WRITER = %w[ADMIN MAINTAIN WRITE].freeze
      SEAM = '.agents/agent-workflow.yml'

      def initialize(root:, host:, environment:, runner:, usage_source:)
        @root = root
        @host = host
        @environment = environment
        @runner = runner
        @usage_source = usage_source
      end

      def call = [github_cli, repository_access, repository_seam, machine_alias, usage_source]

      private

      def github_cli
        _out, error, ok = run(%w[gh auth status])
        return check('GitHub CLI', 'healthy', 'gh is installed and authenticated') if ok

        check('GitHub CLI', 'failed', "gh cannot authenticate: #{first_line(error)}",
              guidance: 'Install the GitHub CLI and run `gh auth login`. Publication and merge need it.')
      end

      # gh resolves the remote itself, so no remote and no access arrive as different answers.
      def repository_access
        out, error, ok = run(['gh', 'repo', 'view', '--json', 'nameWithOwner,viewerPermission'], chdir: @root)
        unless ok
          return check('Repository access', 'skipped', "no GitHub repository resolved here: #{first_line(error)}",
                       guidance: 'Run doctor inside the checkout you intend to publish from.')
        end

        permission(JSON.parse(out))
      rescue JSON::ParserError
        check('Repository access', 'failed', 'gh returned a response that is not repository JSON',
              guidance: 'Check `gh repo view` in this directory.')
      end

      def permission(parsed)
        level = parsed['viewerPermission']
        repository = parsed['nameWithOwner']
        return check('Repository access', 'healthy', "#{repository} is writable as #{level}") if WRITER.include?(level)

        check('Repository access', 'failed', "#{repository} is not writable (#{level || 'no permission'})",
              guidance: 'Use an account with write access, or re-authenticate with `gh auth login`.')
      end

      def repository_seam
        return missing_seam unless File.exist?(File.join(@root, SEAM))

        config = RepositoryConfig.load(root: @root)
        check('Repository seam', 'healthy', "base #{config.base_branch}, merge #{config.merge.fetch('preference')}")
      rescue Shaka::Error, SystemCallError => e
        check('Repository seam', 'failed', "#{SEAM} is not usable: #{first_line(e.message)}",
              guidance: 'Repair the contract, or let `shaka seam init` rewrite a valid one.')
      end

      def missing_seam
        check('Repository seam', 'failed', "this root has no #{SEAM}",
              guidance: 'Run `shaka seam init` here, or point `--root` at the repository you meant.')
      end

      # The alias is published on public pull requests, so doctor asks for a deliberate token
      # and never offers this machine's own name as the value.
      def machine_alias
        value = @environment['SHAKA_MACHINE_ALIAS']
        if value.nil? || value.empty?
          return check('Machine alias', 'degraded', 'SHAKA_MACHINE_ALIAS is unset; provenance will read UNKNOWN',
                       guidance: alias_guidance)
        end
        return check('Machine alias', 'healthy', "provenance will publish #{value}") if valid?(value)

        check('Machine alias', 'failed', 'SHAKA_MACHINE_ALIAS is set to a value publication refuses',
              guidance: alias_guidance)
      end

      def alias_guidance
        'Export SHAKA_MACHINE_ALIAS as a short deliberate token such as `m5`. It appears in public ' \
          "pull requests, so do not use this machine's own name."
      end

      def valid?(value) = ExecutionProvenance::SAFE_VALUE.match?(value)

      def usage_source
        return check('Usage source', 'healthy', "#{@host} transcripts are readable") if @usage_source.call(@host).any?

        check('Usage source', 'degraded', "no readable #{@host} transcript; usage tables will be empty",
              guidance: "Run the task from #{@host} so its session transcript exists, " \
                        'or pass `--file` to `shaka usage`.')
      rescue KeyError, SystemCallError => e
        check('Usage source', 'degraded', first_line(e.message),
              guidance: 'Pass `--host` and `--file` to `shaka usage` explicitly.')
      end

      def check(name, status, summary, guidance: nil)
        { name: name, status: status, summary: summary, guidance: guidance }
      end

      def run(argv, chdir: nil)
        chdir ? Dir.chdir(chdir) { @runner.call(argv) } : @runner.call(argv)
      rescue Errno::ENOENT
        ['', 'gh is not installed', false]
      end

      def first_line(text) = text.to_s.lines.first.to_s.strip
    end
  end
end
