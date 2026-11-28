# frozen_string_literal: true

require 'open3'
require_relative '../doctor/bounded_command'
require_relative '../error'
require_relative '../workflow_version'

module Shaka
  class BranchHead
    # The task branch on origin, read and written under a deadline. Origin and the same-named branch are the only
    # destination: any setting that would send a push elsewhere is refused, so a read and a push cannot diverge.
    class Destination
      SHA = /\A\h{40}\z/
      REMOTE = 'origin'
      READ_SECONDS = 30
      PUSH_SECONDS = 120
      ENVIRONMENT = WorkflowVersion::GIT_ENVIRONMENT.merge('GIT_TERMINAL_PROMPT' => '0').freeze

      def initialize(root:, branch:)
        @root = root
        @branch = branch
      end

      def remote = REMOTE

      # The SHA there, nil when the branch is absent, or { error: } when it cannot be read.
      # ls-remote matches refs by suffix, so only the exact ref counts; a failure or timeout is unreadable.
      def head
        output, error, success = bounded(READ_SECONDS, 'ls-remote', url, "refs/heads/#{@branch}")
        return { error: error.strip.empty? ? 'git ls-remote failed' : error.strip } unless success

        exact_head(output)
      rescue Error => e
        { error: e.message }
      end

      # Pushes one commit to the branch alone, leased on the accepted head; an empty lease means the branch must
      # not exist yet. Tags and submodules stay unpushed whatever push.followTags or push.recurseSubmodules say.
      # Returns false when Git reports the branch already at that commit: someone else put it there.
      def push(accepted, sha)
        raise Error, "origin now pushes somewhere other than #{url}; check again." unless push_url == url

        lease = "--force-with-lease=refs/heads/#{@branch}:#{accepted}"
        output, error, success = bounded(PUSH_SECONDS, 'push', '--porcelain', '--no-follow-tags',
                                         '--recurse-submodules=no', lease, REMOTE, "#{sha}:refs/heads/#{@branch}")
        unless success
          raise Error, "git push of #{sha} to origin/#{@branch} was refused, failed, or timed out, so it may " \
                       "have landed: #{error.strip}"
        end

        output.lines.none? { |line| line.start_with?("=\t") }
      end

      # Resolved once per command, so the read and the push name the same URL.
      def url
        @url ||= push_url
      end

      private

      def push_url
        refuse_redirected_push
        urls = git_lines('remote', 'get-url', '--push', '--all', REMOTE)
        raise Error, "origin has #{urls.size} push URLs; configure one for the task branch." unless urls.one?
        # Edge whitespace or a control character reads differently in ls-remote than in push, so it pauses instead.
        raise Error, "origin's push URL has edge whitespace or control characters." if odd_url?(urls.first)

        reread = git_lines('ls-remote', '--get-url', urls.first)
        raise Error, 'insteadOf rewrites the origin push URL again; configure a direct push URL.' unless reread == urls

        urls.first
      end

      # Settings that would make a plain push of this branch go somewhere other than origin's same-named branch.
      def odd_url?(url) = url != url.strip || url.match?(/[[:cntrl:]]/)

      def refuse_redirected_push
        reason = push_setting_redirect || upstream_redirect || origin_redirect
        raise Error, reason if reason
      end

      def push_setting_redirect
        ["branch.#{@branch}.pushRemote", 'remote.pushDefault'].each do |key|
          value = config_values(key).last # Git uses the last value of a repeated key.
          return "#{key} sends pushes to #{value.inspect}; Shaka pushes to origin only." if value && value != REMOTE
        end
        nil
      end

      # A plain push follows the branch upstream, a named remote or a URL, so any upstream besides origin redirects it.
      def upstream_redirect
        upstream = config_values("branch.#{@branch}.remote").last
        return if upstream.nil? || upstream == REMOTE

        "#{@branch} tracks #{upstream.inspect}; Shaka pushes to origin only."
      end

      def origin_redirect
        return 'origin has a push refspec; remove remote.origin.push.' if config_values('remote.origin.push').any?

        # A mirror remote refuses the single-branch push, so it pauses at the check, not at the push.
        # Git's own boolean parser decides, since `2` and a valueless key both read as true.
        mirror = config_values('remote.origin.mirror', '--type=bool').last
        'origin is set to mirror pushes; remove remote.origin.mirror.' if mirror == 'true'
      end

      # git config exits 1 for a missing key; any other failure is a failed read, never "not configured".
      # Empty values stay, since an empty last value still overrides an earlier origin.
      def config_values(key, *type)
        output, error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, 'config', '-z', *type, '--get-all', key)
        return [] if status.exitstatus == 1
        raise Error, "Cannot read #{key}: #{error.strip}" unless status.success?

        # NUL-delimited, so a value containing a newline stays one value and an empty value is still a value.
        output.split("\0", -1)[0...-1]
      end

      def git_lines(*)
        output, error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, *)
        raise Error, "git #{[*].first(2).join(' ')} failed: #{error.strip}" unless status.success?

        # Only Git's newline goes, and empty lines stay, so a URL ending in a newline counts as two and pauses.
        output.lines.map { |line| line.delete_suffix("\n") }
      end

      def exact_head(output)
        shas = output.lines.filter_map do |line|
          sha, ref = line.chomp.split("\t", 2)
          sha if ref == "refs/heads/#{@branch}"
        end
        return shas.first if shas.length == 1 && shas.first.match?(SHA)

        shas.empty? ? nil : { error: "Unexpected ls-remote output for refs/heads/#{@branch}." }
      end

      def bounded(seconds, *arguments)
        Doctor::BoundedCommand.new(timeout: seconds).call([ENVIRONMENT, 'git', '-C', @root, *arguments])
      rescue SystemCallError => e
        ['', e.message, false]
      end
    end
  end
end
