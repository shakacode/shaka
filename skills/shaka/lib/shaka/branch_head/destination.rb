# frozen_string_literal: true

require 'open3'
require_relative '../doctor/bounded_command'
require_relative '../error'
require_relative '../workflow_version'

module Shaka
  class BranchHead
    # The remote branch a push of the checked-out branch writes to, read and written under a deadline.
    class Destination
      SHA = /\A\h{40}\z/
      READ_SECONDS = 30
      PUSH_SECONDS = 120
      ENVIRONMENT = WorkflowVersion::GIT_ENVIRONMENT.merge('GIT_TERMINAL_PROMPT' => '0').freeze

      attr_reader :remote

      def initialize(root:, branch:)
        @root = root
        @branch = branch
        @remote = push_remote
      end

      # The SHA there, nil when the branch is absent, or { error: } when it cannot be read.
      # Reads the URL a push writes to, which may differ from the fetch URL. ls-remote matches refs by suffix,
      # so only the exact ref counts; a failure or timeout is unreadable, never absent.
      def head
        output, error, success = bounded(READ_SECONDS, 'ls-remote', push_url, "refs/heads/#{@branch}")
        return { error: error.strip.empty? ? 'git ls-remote failed' : error.strip } unless success

        exact_head(output)
      rescue Error => e
        { error: e.message }
      end

      # Pushes one commit to the branch alone, leased on the accepted head; an empty lease means the branch must
      # not exist yet. Tags and submodules stay unpushed whatever push.followTags or push.recurseSubmodules say.
      def push(accepted, sha)
        lease = "--force-with-lease=refs/heads/#{@branch}:#{accepted}"
        _output, error, success = bounded(PUSH_SECONDS, 'push', '--quiet', '--no-follow-tags',
                                          '--recurse-submodules=no', lease, @remote, "#{sha}:refs/heads/#{@branch}")
        return if success

        raise Error, "git push of #{sha} to #{@remote}/#{@branch} was refused, failed, or timed out, so it may " \
                     "have landed: #{error.strip}"
      end

      private

      # The one URL a push of this branch writes to. Configurations where the read could reach another branch or
      # repository than the push are refused rather than guessed: a custom push refspec, a push remote other than
      # the branch's same-named upstream, several push URLs, or a URL that insteadOf would rewrite again on read.
      def push_url
        refuse_redirected_push
        urls = git_lines('remote', 'get-url', '--push', '--all', @remote)
        raise Error, "#{@remote} has #{urls.size} push URLs; configure one for the task branch." unless urls.one?

        reread = git_lines('ls-remote', '--get-url', urls.first)
        raise Error, "insteadOf rewrites #{urls.first} again; configure a direct push URL." unless reread == urls

        urls.first
      end

      def refuse_redirected_push
        if config_values("remote.#{@remote}.push").any?
          raise Error, "#{@remote} has a custom push refspec; push the task branch by hand."
        end

        upstream_mismatch
      end

      def upstream_mismatch
        upstream = config_values("branch.#{@branch}.remote").first
        return unless upstream && upstream != @remote
        return unless config_values("branch.#{@branch}.merge").first == "refs/heads/#{@branch}"

        raise Error, "#{@branch} tracks #{upstream}/#{@branch} but pushes to #{@remote}; make them agree."
      end

      # git config exits 1 for a missing key; any other failure is a failed read, never "not configured".
      def config_values(key)
        output, error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, 'config', '--get-all', key)
        return [] if status.exitstatus == 1
        raise Error, "Cannot read #{key}: #{error.strip}" unless status.success?

        output.lines.map(&:strip).reject(&:empty?)
      end

      def git_lines(*)
        output, error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, *)
        raise Error, "git #{[*].first(2).join(' ')} failed: #{error.strip}" unless status.success?

        output.lines.map(&:strip).reject(&:empty?)
      end

      def exact_head(output)
        shas = output.lines.filter_map do |line|
          sha, ref = line.chomp.split("\t", 2)
          sha if ref == "refs/heads/#{@branch}"
        end
        return shas.first if shas.length == 1 && shas.first.match?(SHA)

        shas.empty? ? nil : { error: "Unexpected ls-remote output for refs/heads/#{@branch}." }
      end

      # Git's own push order: the branch's pushRemote, then remote.pushDefault, then its upstream remote.
      def push_remote
        ["branch.#{@branch}.pushRemote", 'remote.pushDefault', "branch.#{@branch}.remote"].each do |key|
          output, _error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, 'config', '--get', key)
          return output.strip if status.success? && !output.strip.empty? && output.strip != '.'
        end
        'origin'
      end

      def bounded(seconds, *arguments)
        Doctor::BoundedCommand.new(timeout: seconds).call([ENVIRONMENT, 'git', '-C', @root, *arguments])
      rescue SystemCallError => e
        ['', e.message, false]
      end
    end
  end
end
