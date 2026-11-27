# frozen_string_literal: true

require_relative 'locations'
require_relative 'package'
require_relative 'refusal'
require_relative 'settings_location'

module Shaka
  module Install
    # Refuses a checkout that is a linked worktree. For a worktree of a registered installation, a reinstall
    # would only meet that installation's own refusal of the worktree, so the step is the one status gives.
    module CheckoutOwnedWorktree
      # A worktree disappears when its branch merges, taking every host link with it, so no action proceeds.
      def refuse_linked_worktree
        return unless File.file?(File.join(@root, '.git'))

        git_directory, common = git('rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir').split("\n")
        return if git_directory == common

        owner = File.dirname(common)
        step = owned_worktree_step(owner)
        detail = "Installation checkout #{@root} is a linked worktree of #{owner}."
        raise ArgumentError, "#{detail} Install from a separate clone. Next: #{fresh_install}" unless step

        raise ArgumentError, "#{detail} That installation refuses its own worktrees. Next: #{step.values.first}"
      end

      private

      # nil when the owner is not a registered installation, so the caller keeps its reinstall step.
      def owned_worktree_step(owner)
        # Loaded here because the status classes require Official, which requires Checkout.
        require_relative 'status_inventory'
        checkout = StatusInventory.new(source: owner, home: Dir.home).checkouts[real_owner(owner)]
        return unless checkout
        return unsafe_owner_step(checkout) unless checkout.safe?

        guard_links(checkout, checkout.development_step)
      rescue ArgumentError
        checkout && status_decision(checkout)
      end

      def real_owner(owner)
        File.realpath(owner)
      rescue SystemCallError
        nil
      end

      # Another account may control an unsafe checkout's files, so the step is status's repair, never that
      # checkout's own installer.
      def unsafe_owner_step(checkout)
        finding = checkout.findings.compact.first
        return status_decision(checkout) unless finding

        finding['next_command'] ? { command: finding['next_command'] } : { decision: finding['decision'] }
      end

      def status_decision(checkout)
        { decision: Refusal.decide("how to repair the installation at #{checkout.root}",
                                   'to see what needs repair', "#{checkout.installer} --status") }
      end

      # A link into any worktree the installation hosts breaks when the default location's step removes them,
      # and stops a take-over, which moves only links into the installation itself.
      def guard_links(checkout, step)
        return step unless step[:command]

        links = links_into(checkout, checkout.linked_worktrees)
        return step if links.empty?

        { decision: Refusal.decide("where the skills links #{Refusal.paths(links)} should point; they resolve " \
                                   "into worktrees of #{checkout.root}",
                                   'once they point elsewhere', step[:command]) }
      end

      def links_into(checkout, worktrees)
        link_folders(checkout).flat_map { |folder| Package::ALLOWED.map { |name| File.join(folder, name) } }
                              .select { |link| File.symlink?(link) && inside?(link, worktrees) }
      end

      # The host folders, the owner's recorded folders, and a requested skills folder.
      def link_folders(checkout)
        hosts = Locations::HOSTS.values.map { |folder| File.join(Dir.home, folder) }
        requested = [@skills_dir].compact.map { File.expand_path(it) }
        (hosts + checkout.record['targets'].map { |target| target['directory'] } + requested).uniq
      end

      def inside?(link, worktrees)
        resolved = File.realpath(link)
        worktrees.any? { |root| resolved.start_with?("#{SettingsLocation.real(root) || root}/") }
      rescue SystemCallError
        false
      end
    end
  end
end
