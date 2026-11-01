# frozen_string_literal: true

require 'json'
require 'rubygems/version'
require_relative '../error'
require_relative '../ruby_requirement'
require_relative '../configuration'
require_relative 'check'
require_relative 'configured_reviewers'
require_relative 'git_runtime'
require_relative 'machine_alias'
require_relative 'merge_queue_defaults'
require_relative 'repository_access'
require_relative 'usage_source'
require_relative 'reviewer_clis'
require_relative 'installation_state'
require_relative 'settings_source'

module Shaka
  class Doctor
    # Answers one question per check about this machine. Read-only: nothing here writes.
    class Checks
      include Check

      RUBY = RubyRequirement::MINIMUM

      def initialize(root:, host:, environment:, system:, probe_reviewers: false)
        @root = root
        @host = host
        @environment = environment
        @system = system
        @reviewer_clis = ReviewerClis.new(root:, host:, environment:, system:, probe_reviewers:)
      end

      def call
        seam, *basics = brief
        [*basics, seam, reviewer_settings(seam), @reviewer_clis.call(seam),
         MachineAlias.new(@environment, host_name: @system.host_name).call,
         UsageSourceCheck.new(host: @host, system: @system).call, InstallationState.new(system: @system).call]
      end

      # What a task start needs: whose settings the checkout holds, and whether the helper's own
      # prerequisites and the repository work. Reviewer and usage setup stay in the full report.
      def brief
        [repository_seam, ruby_runtime, GitRuntime.new(method(:run)).call, github_cli,
         RepositoryAccess.new(root: @root, run: method(:run)).call,
         MergeQueueDefaults.new(->(argv) { run(argv, chdir: @root) }).call]
      end

      private

      # An older Ruby runs this command and then fails somewhere less obvious, so the declared
      # prerequisite is checked rather than merely printed.
      def ruby_runtime
        running = @system.ruby_version
        return check('Ruby', 'healthy', running) if Gem::Version.new(running) >= Gem::Version.new(RUBY)

        check('Ruby', 'failed', "#{running} is older than the required #{RUBY}",
              guidance: "Rerun bin/install with Ruby #{RUBY} or newer, or set SHAKA_RUBY to one.")
      end

      def github_cli
        out, error, ok = run(%w[gh --version])
        return check('GitHub CLI', 'healthy', first_line(out)) if ok

        check('GitHub CLI', 'failed', "gh does not run: #{first_line(error)}",
              guidance: 'Install https://cli.github.com/, then run `gh auth login` to publish PRs.')
      end

      def reviewer_settings(seam)
        # A warning leaves the settings loadable; only a failed seam stops this check.
        return seam_settings if seam[:status] == 'failed'

        notices = configured_notices
        return known_settings if notices.empty?

        check('Reviewer settings', setting_status(notices), setting_summary(notices),
              guidance: setting_guidance(notices))
      rescue Shaka::Error, SystemCallError => e
        check('Reviewer settings', 'failed', "not checked: #{first_line(e.message)}",
              guidance: 'Repair the repository seam, then run doctor again.')
      end

      def seam_settings
        check('Reviewer settings', 'degraded', 'not checked: repository seam is not healthy',
              guidance: 'Repair the repository seam, then run doctor again.')
      end

      def configured_notices = ConfiguredReviewers.notices(Configuration.worktree(root: @root))

      def setting_status(notices) = notices.any? { |n| n.fetch('severity') == 'failed' } ? 'failed' : 'degraded'

      def known_settings = check('Reviewer settings', 'healthy', 'no reviewer model or effort notice')

      def setting_summary(notices) = notices.map { |notice| notice.fetch('summary') }.join(' ')

      def setting_guidance(notices) = notices.map { |notice| notice.fetch('guidance') }.uniq.join(' ')

      # This reads the working tree. Doctor takes no authority from the seam, and the workflow
      # revalidates policy from a trusted ref.
      def repository_seam
        return missing_seam unless Configuration.contract_entry?(@root)

        config = Configuration.worktree(root: @root)
        summary = SettingsSource.new(@root, @system.runner).summary(config.config_path)
        return check('Repository seam', 'healthy', summary) if config.warnings.empty?

        check('Repository seam', 'degraded', "#{summary} #{config.warnings.join(' ')}")
      rescue Shaka::Error, SystemCallError => e
        check('Repository seam', 'failed', "repository configuration is not usable: #{first_line(e.message)}",
              guidance: 'Repair the contract, or let `shaka seam init` rewrite a valid one.')
      end

      # A missing contract is distinct from a present but unusable file.
      def missing_seam
        check('Repository seam', 'failed', "this root has no #{Configuration::Paths::CONTRACT} regular file",
              guidance: 'Choose a setup before the task. For a private trial in this clone, ask your coding ' \
                        'agent: Set up Shaka just for me. For team settings in a setup PR, ask: Configure this ' \
                        'repository for Shaka using its existing checks and merge policy ask. Or point `--root` ' \
                        'at the checkout you meant.')
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
