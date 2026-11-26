# frozen_string_literal: true

require_relative 'locations'
require_relative 'package'
require_relative 'refusal'

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

        raise ArgumentError, "#{detail} That installation refuses its own worktrees, so clear this one " \
                             "first. Next: #{step.values.first}"
      end

      private

      # nil when the owner is not a registered installation, so the caller keeps its reinstall step.
      def owned_worktree_step(owner)
        require_relative 'status_inventory'
        checkout = StatusInventory.new(source: owner, home: Dir.home).checkouts[real_owner(owner)]
        return unless checkout
        return status_decision(checkout) unless checkout.safe?

        links = links_into_worktree(checkout)
        step = checkout.development_step
        return step unless links.any? && step[:command]

        { decision: Refusal.decide("whether to keep the skills links #{Refusal.paths(links)}, which resolve " \
                                   "into #{@root}", 'to remove the worktree and those links with it',
                                   step[:command]) }
      end

      def real_owner(owner)
        File.realpath(owner)
      rescue SystemCallError
        nil
      end

      # Status reports what keeps an unsafe checkout from being read; Git reads its config, so this does not.
      def status_decision(checkout)
        { decision: Refusal.decide("how to repair the installation at #{checkout.root}",
                                   'to see what needs repair', "#{checkout.installer} --status") }
      end

      def links_into_worktree(checkout)
        link_folders(checkout).flat_map { |folder| Package::ALLOWED.map { |name| File.join(folder, name) } }
                              .select { |link| File.symlink?(link) && inside_worktree?(link) }
      end

      # The host folders, the owner's recorded folders, and a requested skills folder.
      def link_folders(checkout)
        hosts = Locations::HOSTS.values.map { |folder| File.join(Dir.home, folder) }
        requested = [@skills_dir].compact.map { File.expand_path(it) }
        (hosts + checkout.record['targets'].map { |target| target['directory'] } + requested).uniq
      end

      def inside_worktree?(link)
        File.realpath(link).start_with?("#{@root}/")
      rescue SystemCallError
        false
      end
    end
  end
end
