# frozen_string_literal: true

require 'open3'
require 'timeout'
require_relative '../workflow_version'

module Shaka
  module Evidence
    # Fetches the base branch and counts the commits the head lacks, so a long check
    # does not start on a head that will need a rebase and a rerun anyway.
    class BaseFreshness
      FETCH_SECONDS = 60
      # A fetch must never wait for a password prompt; a failure reports the count as unknown.
      ENVIRONMENT = WorkflowVersion::GIT_ENVIRONMENT.merge('GIT_TERMINAL_PROMPT' => '0').freeze

      def self.check(root:, base:)
        new(root, base).check
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

      def initialize(root, base)
        @root = root
        @base = base
      end

      def check
        return unknown("#{@base} is not a branch name") unless git('check-ref-format', '--branch', @base)

        remote = "refs/remotes/origin/#{@base}"
        return unknown("cannot fetch origin #{@base}") unless fetch(remote)

        count = git('rev-list', '--count', "HEAD..#{remote}")
        count ? { 'base' => @base, 'behind' => Integer(count) } : unknown("cannot compare HEAD with #{remote}")
      end

      private

      # A stalled fetch is killed rather than left running after the check gives up on it.
      def fetch(remote)
        pid = Process.spawn(ENVIRONMENT, 'git', '-C', @root, 'fetch', '--quiet', '--no-tags', 'origin',
                            "+refs/heads/#{@base}:#{remote}", in: File::NULL, out: File::NULL, err: File::NULL)
        Timeout.timeout(FETCH_SECONDS) { Process.wait2(pid).last.success? }
      rescue Timeout::Error
        Process.kill('KILL', pid)
        Process.wait(pid)
        false
      rescue SystemCallError
        false
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
