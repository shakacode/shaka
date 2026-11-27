# frozen_string_literal: true

module Shaka
  module Install
    # Reads the work a development cleanup would remove. Each read answers true, false, or nil when Git could
    # not answer, so a failed read is reported as unverified and never taken for work to discard.
    module CheckoutHeldWork
      private

      # The work found, and what Shaka could not verify.
      def held_work(worktrees, branches)
        checks = branches.map do |name|
          merged = merge_answer(name)
          ["the unmerged commits on branch #{name}", "whether branch #{name} is merged", merged.nil? ? nil : !merged]
        end
        checks += worktrees.flat_map { |entry| worktree_holds(entry) }
        [checks.select { |check| check[2] }.map(&:first), checks.select { |check| check[2].nil? }.map { it[1] }]
      end

      # Git reads a worktree's config and attributes, which can name commands, so a folder the directory
      # check refuses, or one that is gone, gets no Git read and goes to a person.
      def worktree_holds(entry)
        path = entry[:path]
        return [["worktree #{path}, which Shaka cannot read safely", nil, true]] unless safe_worktree?(path)

        [["locked worktree #{path}", nil, entry[:locked]],
         ["the uncommitted files in #{path}", "whether #{path} has uncommitted files", changed?(path)],
         ["the commits only detached worktree #{path} holds",
          "whether detached worktree #{path} holds the only copy of its commits", stranded?(entry)],
         ["the submodules in #{path}", "whether #{path} holds submodules", submodules?(path)]]
      end

      def safe_worktree?(path)
        verify_safe_directory(path, 'Linked worktree')
        true
      rescue ArgumentError
        false
      end

      # git branch -d accepts a branch merged into the remote branch it tracks, or into HEAD when it has none or
      # its remote branch is gone; rev-parse exits 1 for both. Any other failure is a read that proves nothing.
      def merge_answer(name)
        output, _error, found = run_git('rev-parse', '--verify', '--quiet', "#{name}@{upstream}")
        return unless [0, 1].include?(found.exitstatus)

        upstream = found.success? ? output.strip : 'HEAD'
        _output, _error, answer = run_git('merge-base', '--is-ancestor', "refs/heads/#{name}", upstream)
        { 0 => true, 1 => false }[answer.exitstatus]
      end

      # No fsmonitor hook: a status read must not start a program the checkout's config names. Ignored files
      # count, because git worktree remove deletes them without asking.
      def changed?(path)
        !git('-c', 'core.fsmonitor=false', '-C', path, '--no-optional-locks', 'status', '--porcelain',
             '--untracked-files=all', '--ignored').empty?
      rescue ArgumentError
        nil
      end

      # git worktree remove refuses a worktree whose index holds a submodule.
      def submodules?(path)
        git('-c', 'core.fsmonitor=false', '-C', path, 'ls-files', '--stage').match?(/^160000 /)
      rescue ArgumentError
        nil
      end

      def stranded?(entry)
        entry[:detached] &&
          git('for-each-ref', '--contains', entry[:head], '--count=1', 'refs/heads', 'refs/remotes').empty?
      rescue ArgumentError
        nil
      end
    end
  end
end
