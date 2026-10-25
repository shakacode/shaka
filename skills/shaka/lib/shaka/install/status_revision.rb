# frozen_string_literal: true

module Shaka
  module Install
    # Compares a checkout's HEAD with its recorded revision and the last-fetched origin branch.
    module StatusRevision
      private

      def branch
        return release_branch if @release

        current = value('branch', '--show-current').to_s
        return tracked_branch if current == @record['branch']

        finding('B4', "checkout is on #{current.empty? ? 'a detached HEAD' : current}; " \
                      "the record expects #{@record['branch']}",
                command: "#{keep_detached if current.empty?}#{git_command} switch #{command(@record['branch'])}")
      end

      # Switching away from a detached HEAD strands commits no branch holds, so they go on a branch first.
      def keep_detached
        held = value('for-each-ref', '--contains', 'HEAD', '--count=1', 'refs/heads', 'refs/remotes')
        "#{git_command} branch kept-#{value('rev-parse', '--short', 'HEAD')} && " unless held&.match?(/\S/)
      end

      # Verification and update both require the branch to track origin's branch of the same name.
      # Reading the config, not the ref, leaves a missing tracking ref to the revision check.
      def tracked_branch
        name = @record['branch']
        remote, merge = %w[remote merge].map { |key| value('config', '--get', "branch.#{name}.#{key}") }
        return if remote == 'origin' && merge == "refs/heads/#{name}"

        tracked = remote ? "#{remote}/#{merge.to_s.delete_prefix('refs/heads/')}" : 'no remote branch'
        finding('B4', "#{name} tracks #{tracked}, not origin/#{name}",
                command: "#{git_command} branch -u origin/#{command(name)}")
      end

      def release_branch
        return if value('branch', '--show-current') == '' &&
                  value('rev-parse', "refs/tags/v#{@release}^{commit}") == recorded

        finding('B4', "release #{@release} no longer has its recorded detached checkout",
                decision: 'Keep this checkout and investigate its HEAD and release tag before reinstalling.')
      end

      def revision
        head = value('rev-parse', 'HEAD')
        return if head.nil? || head == @record['pending_revision']
        return untracked unless value('rev-parse', '--verify', '--quiet', tracking)
        return rewritten unless ancestor?(recorded, tracking)

        moved(head) unless head == recorded
      end

      def moved(head)
        return pulled(head) if ancestor?(recorded, head) && ancestor?(head, tracking)
        return behind(head) if ancestor?(head, recorded)

        local_commits(head)
      end

      # The commits stay on a new branch; reset --keep refuses rather than overwrite an edited file.
      def local_commits(head)
        finding('B2', "checkout #{head[0, 7]} has commits that #{tracking_name} lacks (recorded #{recorded[0, 7]}); " \
                      'the step keeps them on a branch and returns the checkout to its record',
                command: "#{keep_commits(head)}#{git_command} reset --keep #{command(recorded)}")
      end

      # A kept branch left by an earlier attempt already holds these commits, so the step can run again.
      def keep_commits(head)
        name = "kept-#{value('rev-parse', '--short', 'HEAD')}"
        kept = value('rev-parse', '--verify', '--quiet', "refs/heads/#{name}")
        "#{git_command} branch #{command(name)} && " unless kept == head
      end

      def behind(head)
        finding('B11', "checkout #{head[0, 7]} is behind its recorded revision #{recorded[0, 7]}",
                command: "#{git_command} merge --ff-only #{command(recorded)}")
      end

      def rewritten
        finding('B6', "#{tracking_name} no longer contains the recorded revision #{recorded[0, 7]}; " \
                      'offline status sees this only after a fetch',
                decision: "Origin history was rewritten; decide which revision #{@record['branch']} should use.")
      end

      def untracked
        if @record['release']
          return finding('B4', "#{tracking_name} is missing from the checkout",
                         decision: 'Investigate the missing release tag before reinstalling; keep the recorded commit.')
        end
        finding('B4', "#{tracking_name} is missing from the checkout, so its revision cannot be compared",
                command: "#{git_command} fetch origin #{command(@record['branch'])}")
      end

      def pulled(head)
        finding('B1', "checkout #{head[0, 7]} is a pull of #{tracking_name} past the recorded #{recorded[0, 7]}",
                command: "#{installer} --update")
      end

      def recorded = @record['revision']

      def tracking
        @record['release'] ? "refs/tags/v#{@record['release']}" : "refs/remotes/origin/#{@record['branch']}"
      end

      def tracking_name = @record['release'] ? "release #{@record['release']}" : "origin/#{@record['branch']}"
    end
  end
end
