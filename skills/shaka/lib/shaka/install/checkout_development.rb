# frozen_string_literal: true

require_relative 'locations'
require_relative 'refusal'
require_relative 'settings_location'

module Shaka
  module Install
    # Finds linked worktrees and extra local branches, which mean the source checkout is used for development.
    module CheckoutDevelopment
      # Installation refuses development use; maintenance only warns, so an existing install keeps working.
      def check_development_use(action)
        uses = development_uses
        return if uses.empty?

        detail = "Installation checkout #{@root} is also used for development (#{uses.join('; ')})."
        step = "Next: #{development_step.values.first}"
        raise ArgumentError, "#{detail} #{step}" if action == :install

        warn "Warning: #{detail} Pulls, branches, and commits there stop updates. #{step}"
      end

      # A worktree disappears when its branch merges, taking every host link with it, so no action proceeds.
      def refuse_linked_worktree
        return unless File.file?(File.join(@root, '.git'))

        git_directory, common = git('rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir').split("\n")
        return if git_directory == common

        raise ArgumentError, "Installation checkout #{@root} is a linked worktree of #{File.dirname(common)}. " \
                             "Install from a separate clone. Next: #{fresh_install}"
      end

      private

      # The installer and status give the same step. The default location cannot hand its hosts to a fresh
      # checkout there, so it clears the development itself; anywhere else the hosts move to a fresh checkout.
      def development_step
        home = Dir.home
        return clear_development if @root == SettingsLocation.real(SettingsLocation.default_directory(home))
        return { command: fresh_install } unless @record

        command = SettingsLocation.take_over(@root, home, @record)
        command ? { command: } : { decision: SettingsLocation.decision(home) }
      end

      # The installer passes the same selections into the default location; status always has a record.
      def fresh_install
        @fresh_install ||
          Refusal.command(File.join(@root, 'bin/install'), '--directory', SettingsLocation.default_directory(Dir.home))
      end

      # Removes only what Git's own checks allow: clean, unlocked worktrees and merged branches. Work that
      # nothing else holds is named for a person, with the step that discards it.
      def clear_development
        worktrees = worktree_entries
        branches = extra_branches
        held = held_work(worktrees, branches)
        return { command: removal(worktrees, branches, discard: false) } if held.empty?

        { decision: Refusal.decide("whether to keep #{Refusal.paths(held)}", 'to discard that work and clear ' \
                                                                             'this checkout',
                                   removal(worktrees, branches, discard: true)) }
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

      def held_work(worktrees, branches)
        branches.reject { |name| merged?(name) }.map { |name| "the unmerged commits on branch #{name}" } +
          worktrees.flat_map { |entry| worktree_holds(entry) }
      end

      # Git reads a worktree's config and attributes, which can name commands, so a folder the directory
      # check refuses, or one that is gone, gets no Git read and goes to a person.
      def worktree_holds(entry)
        path = entry[:path]
        verify_safe_directory(path, 'Linked worktree')
        { "locked worktree #{path}" => entry[:locked], "the uncommitted files in #{path}" => changed?(path),
          "the commits only detached worktree #{path} holds" => stranded?(entry),
          "the submodules in #{path}" => submodules?(path) }.select { |_held, found| found }.keys
      rescue ArgumentError
        ["worktree #{path}, which Shaka cannot read safely"]
      end

      # git branch -d accepts a branch merged into the remote branch it tracks, or into HEAD when it has none.
      def merged?(name) = ancestor?("refs/heads/#{name}", tracked(name) || 'HEAD')

      def tracked(name)
        git('rev-parse', '--verify', '--quiet', "#{name}@{upstream}")
      rescue ArgumentError
        nil
      end

      # No fsmonitor hook: a status read must not start a program the checkout's config names. Ignored files
      # count, because git worktree remove deletes them without asking.
      def changed?(path)
        !git('-c', 'core.fsmonitor=false', '-C', path, '--no-optional-locks', 'status', '--porcelain',
             '--untracked-files=all', '--ignored').empty?
      rescue ArgumentError
        true
      end

      # git worktree remove refuses a worktree whose index holds a submodule.
      def submodules?(path)
        git('-c', 'core.fsmonitor=false', '-C', path, 'ls-files', '--stage').match?(/^160000 /)
      end

      def stranded?(entry)
        entry[:detached] &&
          git('for-each-ref', '--contains', entry[:head], '--count=1', 'refs/heads', 'refs/remotes').empty?
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

      def linked_worktrees = worktree_entries.map { |entry| entry[:path] }

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
