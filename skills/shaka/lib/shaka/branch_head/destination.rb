# frozen_string_literal: true

require 'open3'
require 'uri'
require_relative '../doctor/bounded_command'
require_relative '../error'
require_relative '../git_origin'
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

      # pr_head, when given, is the PR's head as { 'url' => 'https://HOST/OWNER/NAME', 'branch' => NAME }; origin
      # must be that repository and the checked-out branch that branch.
      def initialize(root:, branch:, pr_head: nil)
        @root = root
        @branch = branch
        @pr_head = pr_head
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
        @url ||= push_url.tap { |resolved| refuse_other_pr_head(resolved) }
      end

      private

      def refuse_other_pr_head(resolved)
        return unless @pr_head

        repository = repository_key(resolved)
        return if @pr_head['branch'] == @branch && repository_key(@pr_head['url']) == repository

        raise Error, "The PR head is #{@pr_head['url']}:#{@pr_head['branch']}, but origin is " \
                     "#{repository}:#{@branch}; work on the PR head from a checkout whose origin holds it."
      end

      # Host and repository path, whatever the transport, so an SSH origin matches the PR's https URL.
      def repository_key(url)
        uri = URI(GitOrigin.canonical_url(url))
        "#{uri.host}#{uri.path}".downcase
      rescue Error, URI::Error
        url
      end

      def push_url
        refuse_redirected_push
        urls = git_lines('remote', 'get-url', '--push', '--all', REMOTE)
        raise Error, "origin has #{urls.size} push URLs; configure one for the task branch." unless urls.one?

        reread = git_lines('ls-remote', '--get-url', urls.first)
        raise Error, 'insteadOf rewrites the origin push URL again; configure a direct push URL.' unless reread == urls

        urls.first
      end

      # Settings that would make a plain push of this branch go somewhere other than origin's same-named branch.
      def refuse_redirected_push
        ["branch.#{@branch}.pushRemote", 'remote.pushDefault'].each do |key|
          value = config_values(key).last # Git uses the last value of a repeated key.
          if value && value != REMOTE
            raise Error,
                  "#{key} sends pushes to #{value}; Shaka pushes task branches to origin only."
          end
        end
        return unless config_values('remote.origin.push').any?

        raise Error,
              'origin has a custom push refspec; remove remote.origin.push.'
      end

      # git config exits 1 for a missing key; any other failure is a failed read, never "not configured".
      # Empty values stay, since an empty last value still overrides an earlier origin.
      def config_values(key)
        output, error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, 'config', '--get-all', key)
        return [] if status.exitstatus == 1
        raise Error, "Cannot read #{key}: #{error.strip}" unless status.success?

        output.lines.map(&:chomp)
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

      def bounded(seconds, *arguments)
        Doctor::BoundedCommand.new(timeout: seconds).call([ENVIRONMENT, 'git', '-C', @root, *arguments])
      rescue SystemCallError => e
        ['', e.message, false]
      end
    end
  end
end
