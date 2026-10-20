# frozen_string_literal: true

require 'open3'
require 'shellwords'
require_relative 'settings_location'
require_relative 'status_states'

module Shaka
  module Install
    # Reports source checkouts Shaka no longer supports, each with the one command that replaces it. A linked
    # worktree is cloned again into the default location; a checkout under the settings path is taken over.
    class StatusUnsupported
      DECIDE = "Reinstall into ~/#{Locations::SOURCE} from the branch you use, with the hosts, skills " \
               'folders, and towers you use (one bin/install run per host whose towers differ); ' \
               'see official-installation.md.'.freeze

      SETTINGS_DETAIL = "the source checkout sits under ~/#{Locations::SETTINGS}, where Shaka keeps settings; " \
                        'move its links to a checkout at '.freeze

      def initialize(inventory)
        @inventory = inventory
      end

      def findings
        settings_location + @inventory.worktrees.map do |root|
          replace('C3', root, 'the source checkout is a linked worktree, which goes away when its branch is cleaned up',
                  selected(root, @inventory.links_to(root)))
        end
      end

      private

      # A registered checkout under the settings folder in HOME.
      def settings_location
        home = @inventory.home
        old = @inventory.checkouts.values.select { |checkout| SettingsLocation.inside?(checkout.root, home) }
        old.map do |checkout|
          command = SettingsLocation.take_over(checkout.root, home, checkout.record)
          StatusStates.finding('E1', checkout.root, SETTINGS_DETAIL + @inventory.default_directory,
                               command:, decision: (SettingsLocation.decision(home) unless command))
        end
      end

      # The host folders and skills the worktree serves, and the origin to clone it from again.
      def selected(root, links)
        hosts = links.group_by { |link| File.dirname(link['path']) }
        { 'directories' => hosts.keys, 'names' => links.map { |link| link['name'] },
          'targets' => hosts.values.map { |group| group.map { |link| link['name'] }.sort },
          'repository' => origin(root), 'branch' => tracked(root) }
      end

      # Reading one config value or ref runs no program the checkout's config names.
      def origin(root) = read(root, 'config', '--get', 'remote.origin.url')

      # The origin branch the worktree tracks; nil when it tracks none.
      def tracked(root)
        branch = read(root, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
        branch.delete_prefix('origin/') if branch&.start_with?('origin/')
      end

      def read(root, *)
        environment = ENV.keys.grep(/\AGIT_/).to_h { |key| [key, nil] }
        output, process = Open3.capture2e(environment, 'git', '-C', root, *)
        value = output.strip
        value if process.success? && !value.empty?
      end

      def replace(id, root, reason, selection)
        detail = "#{reason}; reinstall into #{@inventory.default_directory}"
        hosts = hosts(selection['directories'].uniq)
        return StatusStates.finding(id, root, detail, decision: DECIDE) unless hosts && command?(selection)

        install = install_step(selection, hosts)
        StatusStates.finding(id, root, "#{detail}. If the install step fails, the old links come back; fix what it " \
                                       "names, then rerun: #{install}",
                             command: command(selection, @inventory.links_to(root), install))
      end

      # The old links go first, because the installer refuses links another checkout owns; if the install
      # then fails, the command puts them back so the hosts keep a working Shaka.
      def command(selection, links, install)
        steps = ["git clone #{escape('--branch', 'main', repository(selection), @inventory.default_directory)}"]
        return (steps << install).join(' && ') if links.empty?

        steps << "rm -- #{escape(*links.map { |link| link['path'] })}"
        steps << "{ #{install} || { #{restore(links)}; false; }; }"
        steps.join(' && ')
      end

      def restore(links) = links.map { |link| "ln -s #{escape(link['target'], link['path'])}" }.join('; ')

      def install_step(selection, hosts)
        target = @inventory.default_directory
        escape(File.join(target, 'bin/install'), '--directory', target, *source(selection), *hosts, *towers(selection))
      end

      # One command can repeat one selection for every host, into a destination git clone accepts. It
      # reinstalls main: another tracked branch may be a feature branch that goes away, so it gets a decision.
      def command?(selection)
        selection['branch'] == 'main' && !File.exist?(@inventory.default_directory) &&
          selection['targets'].uniq.size == 1 && !StatusStates.credentials?(selection['repository'])
      end

      def repository(selection) = selection['repository'] || Checkout::REPOSITORY

      def source(selection)
        repository(selection) == Checkout::REPOSITORY ? [] : ['--repository', repository(selection)]
      end

      # Hosts take --agent; one custom folder takes --skills-dir; the installer accepts no mix of the two.
      def hosts(directories)
        agents = directories.map { |directory| agent(directory) }
        return agents.flat_map { |name| ['--agent', name] } if agents.all?

        ['--skills-dir', directories.first] if directories.size == 1
      end

      def agent(directory)
        forms = [File.expand_path(directory), @inventory.real(directory)].compact
        Official::HOSTS.find do |_name, path|
          host = File.join(@inventory.home, path)
          forms.include?(host) || forms.include?(@inventory.real(host))
        end&.first
      end

      def towers(selection) = selection['names'].filter_map { |name| SettingsLocation::TOWERS[name] }.uniq
      def escape(*words) = words.map { |word| Shellwords.escape(word) }.join(' ')
    end
  end
end
