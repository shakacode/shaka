# frozen_string_literal: true

require 'open3'
require_relative '../doctor/bounded_command'
require_relative '../workflow_version'

module Shaka
  module Evidence
    # Fetches the base branch and counts the commits the head lacks, so a long check
    # does not start on a head that will need a rebase and a rerun anyway.
    class BaseFreshness
      FETCH_SECONDS = 60
      # Refuses HTTPS credential prompts; FETCH_SECONDS bounds any other wait, such as an SSH passphrase.
      ENVIRONMENT = WorkflowVersion::GIT_ENVIRONMENT.merge('GIT_TERMINAL_PROMPT' => '0').freeze

      def self.check(root:, base:, fetch_seconds: FETCH_SECONDS)
        new(root, base, fetch_seconds).check
      end

      # Yields to run the check only when the head is not behind the base, and adds the count to its result.
      def self.gate(context, base)
        return yield unless base

        report = check(root: context.fetch(:root), base:)
        behind = report.fetch('behind')
        if behind == 'unknown'
          warn "shaka: cannot tell whether the head is behind origin/#{base}: #{report['reason']}"
        elsif behind.positive?
          return stop(context, report)
        end
        yield.merge('base_behind' => report)
      end

      def self.stop(context, report)
        warn "shaka: head is #{report['behind']} commit(s) behind origin/#{report['base']}; " \
             'update the branch first, then rerun'
        { 'kind' => 'validation', 'command' => context.fetch(:name), 'status' => 'behind_base',
          'base_behind' => report }
      end
      private_class_method :stop

      def initialize(root, base, fetch_seconds)
        @root = root
        @base = base
        @fetch_seconds = fetch_seconds
      end

      def check
        return unknown("#{@base} is not a branch name") unless git('check-ref-format', '--branch', @base)

        remote = "refs/remotes/origin/#{@base}"
        return unknown("cannot fetch origin #{@base}") unless fetch(remote)

        count = git('rev-list', '--count', "HEAD..#{remote}")
        count ? { 'base' => @base, 'behind' => Integer(count) } : unknown("cannot compare HEAD with #{remote}")
      end

      private

      # BoundedCommand ends the fetch's whole process tree at the deadline, including an SSH child.
      def fetch(remote)
        argv = [ENVIRONMENT, 'git', '-C', @root, 'fetch', '--quiet', '--no-tags', 'origin',
                "+refs/heads/#{@base}:#{remote}"]
        Doctor::BoundedCommand.new(timeout: @fetch_seconds).call(argv).last
      end

      def unknown(reason) = { 'base' => @base, 'behind' => 'unknown', 'reason' => reason }

      def git(*)
        output, _error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, *, stdin_data: '')
        output.strip if status.success?
      rescue SystemCallError
        nil
      end
    end
  end
end
