# frozen_string_literal: true

require 'json'
require 'rubygems/version'
require_relative '../error'
require_relative '../repository_config'
require_relative 'check'
require_relative 'machine_alias'
require_relative 'usage_source'

module Shaka
  class Doctor
    # Answers one question per check about this machine. Read-only: nothing here writes.
    class Checks
      include Check

      WRITER = %w[ADMIN MAINTAIN WRITE].freeze
      RUBY = '3.4'
      SEAM = '.agents/agent-workflow.yml'

      def initialize(root:, host:, environment:, system:)
        @root = root
        @host = host
        @environment = environment
        @system = system
      end

      def call
        [ruby_runtime, github_cli, repository_access, repository_seam, alias_check,
         UsageSourceCheck.new(host: @host, system: @system).call]
      end

      private

      def alias_check = MachineAlias.new(@environment, host_name: @system.host_name).call

      # An older Ruby runs this command and then fails somewhere less obvious, so the declared
      # prerequisite is checked rather than merely printed.
      def ruby_runtime
        running = @system.ruby_version
        return check('Ruby', 'healthy', running) if Gem::Version.new(running) >= Gem::Version.new(RUBY)

        check('Ruby', 'failed', "#{running} is older than the required #{RUBY}",
              guidance: "Select Ruby #{RUBY} or newer for the shell that runs this skill.")
      end

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
        repository = stated(parsed, 'nameWithOwner')
        level = stated(parsed, 'viewerPermission')
        return unreachable_repository('gh did not report a repository and a permission') unless repository && level
        return check('Repository access', 'healthy', "#{repository} is writable as #{level}") if WRITER.include?(level)

        check('Repository access', 'failed', "#{repository} is not writable (#{level})",
              guidance: 'Use an account with write access, or re-authenticate with `gh auth login`.')
      end

      # Present, a string, and not blank: anything less states nothing.
      def stated(parsed, field)
        value = parsed[field] if parsed.is_a?(Hash)
        value if value.is_a?(String) && !value.empty?
      end

      # This reads the working tree, so it answers whether this checkout's contract is usable.
      # It deliberately does not restate the seam's commands or merge preference: doctor takes
      # no authority from the seam, and the workflow revalidates policy from a trusted ref.
      def repository_seam
        return missing_seam unless File.file?(File.join(@root, SEAM))

        RepositoryConfig.load(root: @root)
        check('Repository seam', 'healthy', "#{SEAM} loads and validates in this working tree")
      rescue Shaka::Error, SystemCallError => e
        check('Repository seam', 'failed', "#{SEAM} is not usable: #{first_line(e.message)}",
              guidance: 'Repair the contract, or let `shaka seam init` rewrite a valid one.')
      end

      # File.file? rather than File.exist?: reading a FIFO here would block the whole report.
      def missing_seam
        check('Repository seam', 'failed', "this root has no #{SEAM} regular file",
              guidance: 'Run `shaka seam init` here, or point `--root` at the repository you meant.')
      end

      # A command that cannot even launch is this check's answer, never an aborted report.
      # The child is scoped to its directory directly; Dir.chdir would move the whole process.
      def run(argv, chdir: nil)
        @system.runner.call(argv, chdir)
      rescue SystemCallError => e
        ['', first_line(e.message), false]
      end
    end
  end
end
