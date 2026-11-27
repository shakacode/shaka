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
        url, error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, 'remote', 'get-url', '--push', @remote)
        return { error: "Cannot resolve the push URL of #{@remote}: #{error.strip}" } unless status.success?

        output, error, success = bounded(READ_SECONDS, 'ls-remote', url.strip, "refs/heads/#{@branch}")
        return { error: error.strip.empty? ? 'git ls-remote failed' : error.strip } unless success

        exact_head(output)
      end

      # Pushes HEAD leased on the accepted head; an empty lease means the branch must not exist yet.
      def push(accepted)
        lease = "--force-with-lease=refs/heads/#{@branch}:#{accepted}"
        _output, error, success = bounded(PUSH_SECONDS, 'push', '--quiet', lease, @remote,
                                          "HEAD:refs/heads/#{@branch}")
        raise Error, "git push to #{@remote}/#{@branch} was refused or failed: #{error.strip}" unless success
      end

      private

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
