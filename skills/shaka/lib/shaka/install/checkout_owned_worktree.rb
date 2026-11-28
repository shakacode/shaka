# frozen_string_literal: true

require_relative 'settings_location'

module Shaka
  module Install
    # Refuses a checkout that is a linked worktree. A worktree of the installation at the default location
    # cannot be cleared by reinstalling there, which that installation refuses for the same worktree, so it
    # gets the step status gives for that installation's development instead.
    module CheckoutOwnedWorktree
      # A worktree disappears when its branch merges, taking every host link with it, so no action proceeds.
      def refuse_linked_worktree
        return unless File.file?(File.join(@root, '.git'))

        git_directory, common = git('rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir').split("\n")
        return if git_directory == common

        owner = File.dirname(common)
        step = default_worktree_step(owner)
        detail = "Installation checkout #{@root} is a linked worktree of #{owner}."
        raise ArgumentError, "#{detail} Install from a separate clone. Next: #{fresh_install}" unless step

        raise ArgumentError, "#{detail} That installation refuses its own worktrees. Next: #{step.values.first}"
      end

      private

      # nil unless the owner is the installation at the default location, so the caller keeps its reinstall step.
      def default_worktree_step(owner)
        default = SettingsLocation.real(SettingsLocation.default_directory(Dir.home))
        return unless default && SettingsLocation.real(owner) == default

        owner_step(default)
      rescue DirectorySafety::Unsafe => e
        { command: e.step }
      rescue ArgumentError, SystemCallError => e
        reason = e.message.gsub(/\s+/, ' ').chomp('.')
        person_step("how to repair the installation at #{default}, which cannot be read (#{reason})")
      end

      # The installation's own command only when its directories are safe, its record reads, and it hosts this
      # worktree. Directory safety comes first, because Git reads a checkout's config, which can name commands.
      def owner_step(default)
        [default, File.join(default, '.git')].each { verify_safe_directory(it, 'Installation directory') }
        record = Checkout.new(default).read_record
        return unless record

        # Loaded here because the status classes require Official, which requires Checkout.
        require_relative 'status_checkout'
        development_step_for(StatusCheckout.new(default, record))
      end

      def development_step_for(checkout)
        worktrees = checkout.linked_worktrees.map { SettingsLocation.real(it) || it }
        return checkout.development_step if worktrees.include?(@root)

        person_step("how to clear #{@root}, which #{checkout.root} does not list as development")
      end

      # No command: the cases that reach a person are the ones where no printed command is known to be safe.
      def person_step(question) = { decision: "a person must decide #{question}, then run this command again" }
    end
  end
end
