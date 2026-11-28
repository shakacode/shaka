# frozen_string_literal: true

require_relative 'checkout_held_work'
require_relative 'locations'
require_relative 'refusal'
require_relative 'settings_location'
require_relative 'worktree_links'

module Shaka
  module Install
    # Finds linked worktrees and extra local branches, which mean the source checkout is used for development.
    module CheckoutDevelopment
      include CheckoutHeldWork

      # Installation refuses development use; maintenance only warns, so an existing install keeps working.
      def check_development_use(action)
        uses = development_uses
        return if uses.empty?

        detail = "Installation checkout #{@root} is also used for development (#{uses.join('; ')})."
        step = "Next: #{development_step.values.first}"
        raise ArgumentError, "#{detail} #{step}" if action == :install

        warn "Warning: #{detail} Pulls, branches, and commits there stop updates. #{step}"
      end

      # The installer and status give the same step. The default location cannot hand its hosts to a fresh
      # checkout there, so it clears the development itself; anywhere else the hosts move to a fresh checkout.
      def development_step
        home = Dir.home
        return clear_development if @root == SettingsLocation.real(SettingsLocation.default_directory(home))
        return { command: fresh_install } unless @record

        command = SettingsLocation.take_over(@root, home, @record)
        command ? { command: } : { decision: SettingsLocation.decision(home) }
      end

      def linked_worktrees = worktree_entries.map { |entry| entry[:path] }

      private

      # The installer passes the same selections into the default location; status always has a record.
      def fresh_install
        @fresh_install ||
          Refusal.command(File.join(@root, 'bin/install'), '--directory', SettingsLocation.default_directory(Dir.home))
      end

      # Removes only what Git's own checks allow: clean, unlocked worktrees and merged branches. Work that
      # nothing else holds is named for a person, with the step that discards it. A skill link into a worktree
      # would be left pointing at nothing, and a failed Git read proves nothing, so neither gets a command.
      def clear_development
        worktrees = worktree_entries
        linked = linked_step(worktrees)
        return linked if linked

        branches = extra_branches
        held, unread = held_work(worktrees, branches)
        return { decision: unread_decision(unread, held) } unless unread.empty?
        return { command: removal(worktrees, branches, discard: false) } if held.empty?

        { decision: Refusal.decide("whether to keep #{Refusal.paths(held)}", 'to discard that work and clear ' \
                                                                             'this checkout',
                                   removal(worktrees, branches, discard: true)) }
      end

      # The host folders, every folder the installation records, and a folder this run names.
      def link_folders
        hosts = Locations::HOSTS.values.map { |folder| File.join(Dir.home, folder) }
        recorded = @record ? @record.fetch('targets', []).map { |target| target['directory'] } : []
        hosts + recorded + [@skills_dir]
      end

      # Every link is named, since each one left out would need another run to find. A link's name is any file
      # name, so control characters are shown escaped and cannot start a line that reads as another step.
      def linked_step(worktrees)
        links = WorktreeLinks.into(worktrees.map { |entry| entry[:path] }, link_folders)
        return if links.empty?

        { decision: "a person must decide where #{links.map { printable(it) }.join(', ')} should point, because " \
                    'they lead into ' \
                    'the linked worktrees this step would remove, or could not be read to rule that out; repoint ' \
                    'them, then run this command again' }
      end

      def printable(text) = text.chars.map { |character| escaped(character) }.join

      # Control characters, line and paragraph separators, and bytes that are not valid text are shown as \xNN
      # or \uNNNN. A backslash is doubled, so an escaped character cannot be confused with a name that spells one.
      def escaped(character)
        return character.bytes.map { |byte| format('\\x%02X', byte) }.join if raw_bytes?(character)
        return '\\\\' if character == '\\'
        return character unless character.match?(/[[:cntrl:]\p{Zl}\p{Zp}]/)

        format(character.ord > 0xFF ? '\\u%04X' : '\\x%02X', character.ord)
      end

      # Under a non-UTF-8 locale, Ruby reads non-ASCII names as binary or legacy-encoded text, which a Unicode
      # pattern refuses, so those characters are shown as their bytes.
      def raw_bytes?(character)
        !character.valid_encoding? || (character.encoding != Encoding::UTF_8 && !character.ascii_only?)
      end

      # Worktree paths can hold any file name, so they are shown escaped like link names.
      def unread_decision(unread, held)
        also = held.empty? ? '' : ", and whether to keep #{Refusal.paths(held)}"
        printable('a person must decide how to clear this checkout, because Shaka could not verify ' \
                  "#{Refusal.paths(unread)}#{also}; check that work, then run this command again")
      end

      # A second --force removes a locked worktree too. A worktree whose folder was deleted still holds
      # its branch until Git prunes it, so prune goes first.
      def removal(worktrees, branches, discard:)
        steps = worktree_list.any? { |entry| entry[:prunable] } ? [development_git('worktree', 'prune')] : []
        steps += worktrees.map do |entry|
          development_git('worktree', 'remove', *(%w[--force --force] if discard), entry[:path])
        end
        steps << development_git('branch', discard ? '-D' : '-d', *branches) unless branches.empty?
        steps.join(' && ')
      end

      def development_git(*) = Refusal.command('git', '-C', @root, *)

      def development_uses
        worktrees = linked_worktrees
        branches = extra_branches
        uses = []
        uses << "linked worktrees: #{worktrees.join(', ')}" unless worktrees.empty?
        uses << "local branches: #{branches.join(', ')}" unless branches.empty?
        uses
      end

      def extra_branches
        git('for-each-ref', '--format=%(refname:lstrip=2)', 'refs/heads/').lines.map(&:strip) - [@branch]
      end

      # Prunable entries no longer exist on disk. A staging worktree a killed update left is not development;
      # status reports it as B7.
      def worktree_entries = worktree_list.reject { it[:prunable] || [@root, staging_path].include?(it[:path]) }

      # The first entry is the main worktree. -z ends each field with NUL, so a path may hold a newline.
      def worktree_list
        git('worktree', 'list', '--porcelain', '-z').split("\0\0").drop(1).filter_map do |entry|
          fields = entry.split("\0").to_h { |field| field.split(' ', 2).values_at(0, 1) }
          next unless fields['worktree']

          { path: fields['worktree'], head: fields['HEAD'], detached: fields.key?('detached'),
            locked: fields.key?('locked'), prunable: fields.key?('prunable') }
        end
      end
    end
  end
end
