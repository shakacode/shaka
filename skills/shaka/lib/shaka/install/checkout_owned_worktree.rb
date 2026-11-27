# frozen_string_literal: true

require_relative 'locations'
require_relative 'package'
require_relative 'refusal'
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
      rescue ArgumentError, SystemCallError
        person_step("how to clear #{@root} from the installation at #{default}")
      end

      # The installation's own command only when it is safe to read, hosts this worktree, and serves no link
      # from any of its worktrees; otherwise a person decides, with the reason named.
      def owner_step(default)
        record = Checkout.new(default).read_record
        return unless record

        # Loaded here because the status classes require Official, which requires Checkout.
        require_relative 'status_checkout'
        checkout = StatusCheckout.new(default, record)
        return person_step("how to make #{default} safe to read; another account can change it") unless checkout.safe?

        development_step_for(checkout)
      end

      def development_step_for(checkout)
        worktrees = checkout.linked_worktrees.map { SettingsLocation.real(it) || it }
        return person_step("how to clear #{@root}, which #{checkout.root} does not list as development") unless
          worktrees.include?(@root)

        links = links_into(checkout.record, worktrees)
        return checkout.development_step if links.empty?

        person_step("where the skills links #{Refusal.paths(links)} should point; they resolve into " \
                    "worktrees of #{checkout.root}, and clearing them would break those links")
      end

      # No command: the cases that reach a person are the ones where no printed command is known to be safe.
      def person_step(question) = { decision: "a person must decide #{question}, then run this command again" }

      def links_into(record, worktrees)
        link_folders(record).flat_map do |folder|
          Package::ALLOWED.map { |name| File.join(folder, name) }
                          .select { |link| [folder, link].any? { |path| inside?(path, worktrees) } }
        end
      end

      # The host folders, the installation's recorded folders, and a requested skills folder. A skill depends
      # on a worktree through its own link or through a folder linked into one.
      def link_folders(record)
        hosts = Locations::HOSTS.values.map { |folder| File.join(Dir.home, folder) }
        requested = [@skills_dir].compact.map { File.expand_path(it) }
        (hosts + record['targets'].map { |target| target['directory'] } + requested).uniq
      end

      def inside?(path, worktrees)
        resolved = File.realpath(path)
        worktrees.any? { resolved == it || resolved.start_with?("#{it}/") }
      rescue SystemCallError
        false
      end
    end
  end
end
