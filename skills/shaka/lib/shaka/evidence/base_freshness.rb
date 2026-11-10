# frozen_string_literal: true

require 'open3'
require_relative '../doctor/bounded_command'
require_relative '../error'
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
      # The count is printed first, so a long check shows it while running.
      def self.gate(context, base)
        return yield unless base

        report = check(root: context.fetch(:root), base: branch!(base))
        warn notice(report)
        behind = report.fetch('behind')
        if behind.is_a?(Integer) && behind.positive?
          return { 'kind' => 'validation', 'command' => context.fetch(:name), 'status' => 'behind_base',
                   'base_behind' => report }
        end
        yield.merge('base_behind' => report)
      end

      # A revision, revision expression, or remote-tracking name would fail the fetch and quietly turn the stop off.
      def self.branch!(base)
        return base if base.match?(%r{\A[\w.\-/]+\z}) && !base.match?(%r{\A(?:HEAD\z|\h{7,}\z|origin/|refs/)})

        raise Error, "--base takes the base branch name, such as main, not #{base}"
      end

      def self.notice(report)
        base = "origin/#{report['base']}"
        case report['behind']
        when 'unknown' then "shaka: cannot tell whether the head is behind #{base}: #{report['reason']}"
        when 0 then "shaka: head has every commit on #{base}"
        else "shaka: head is #{report['behind']} commit(s) behind #{base}; update the branch first, then rerun"
        end
      end
      private_class_method :branch!, :notice

      def initialize(root, base, fetch_seconds)
        @root = root
        @base = base
        @fetch_seconds = fetch_seconds
      end

      def check
        return unknown("#{@base} is not a branch name") unless git('check-ref-format', '--branch', @base)

        remote = "refs/remotes/origin/#{@base}"
        return unknown("cannot fetch origin #{@base}") unless fetch(remote)

        # A shallow history hides base commits the head already has, so its count would be too high.
        return unknown('the checkout is shallow') unless git('rev-parse', '--is-shallow-repository') == 'false'

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
