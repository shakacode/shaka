# frozen_string_literal: true

module Shaka
  class GitHub
    # Reads `gh pr checks`, including the unprotected empty-list diagnostic.
    module CheckList
      CHECK_EXITS = [0, 1, 8].freeze
      NO_CHECKS = /\Ano checks reported on the '[^\r\n]+' branch(?:\r?\n)?\z/
      NO_REQUIRED_CHECKS = /\Ano required checks reported on the '[^\r\n]+' branch(?:\r?\n)?\z/

      def checks(required: false)
        stdout, stderr, exitstatus = fetch_check_streams(required)
        if stdout.strip.empty?
          return [] if empty_check_list?(stderr, required)
          raise check_failure(exitstatus, stderr) unless exitstatus.zero?
        end

        result = parse_json(stdout)
        raise Error, 'GitHub checks response must be an array.' unless result.is_a?(Array)

        result
      end

      def required_checks
        checks(required: true)
      rescue Error => e
        status = " (HTTP #{e.http_status})" if e.http_status
        raise Error.new("Required-check evidence is unavailable#{status}; " \
                        'confirm native required checks and GitHub access.', http_status: e.http_status)
      end

      private

      def fetch_check_streams(required)
        argv = ['gh', 'pr', 'checks', @number.to_s, '--repo', @repository]
        argv << '--required' if required
        argv.push('--json', 'name,state,bucket,link')
        stdout, stderr, status = @runner.call(argv, stdin_data: '')
        raise check_failure(status.exitstatus, stderr) unless CHECK_EXITS.include?(status.exitstatus)

        [utf8(stdout), utf8(stderr), status.exitstatus]
      rescue Errno::ENOENT
        raise Error, 'GitHub CLI is unavailable; install gh and authenticate.'
      end

      def check_failure(exitstatus, stderr)
        http_status = Error.http_status_in(stderr)
        detail = ["exit #{exitstatus}", ("HTTP #{http_status}" if http_status)].compact.join(', ')
        Error.new("gh pr #{@number} failed (#{detail}).", http_status:)
      end

      def empty_check_list?(stderr, required)
        stderr.match?(NO_CHECKS) || (required && stderr.match?(NO_REQUIRED_CHECKS))
      end
    end
  end
end
