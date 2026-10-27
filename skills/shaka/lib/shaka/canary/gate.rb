# frozen_string_literal: true

require_relative 'pulls'

module Shaka
  module Canary
    # Parses `--name value` pairs. The workflow passes those pairs; tests pass the same argv.
    module Flags
      module_function

      def parse(argv)
        options = {}
        pairs(argv).each { |flag, value| options[name(flag)] = value }
        options
      end

      def pairs(argv)
        raise ArgumentError, 'expected --name value pairs' if argv.size.odd?

        argv.each_slice(2).to_a
      end

      def name(flag)
        raise ArgumentError, "expected a flag, got #{flag.inspect}" unless flag.start_with?('--')

        flag.delete_prefix('--')
      end
    end

    # Holds a push-triggered run until an hour after the previous agent start.
    # A manual dispatch starts immediately. Cancelling superseded runs is the workflow's concurrency group.
    module Throttle
      INTERVAL = 3600

      module_function

      def latest_start(jobs)
        jobs.flat_map { |job| job.fetch('steps') }.filter_map do |step|
          next unless step['name'] == 'Run the fixed task headless' && step['conclusion'] != 'skipped'

          Time.iso8601(step['started_at']) if step['started_at']
        end.max
      end

      def wait_seconds(last_finished_at:, now:, manual:)
        return 0 if manual || last_finished_at.nil?

        remaining = INTERVAL - (now - last_finished_at)
        remaining.positive? ? remaining.ceil : 0
      end
    end

    # Reads the issue 899 stats line. A missing amount stays UNKNOWN, never zero.
    module Spend
      PATTERN = /AI spend\s+(\$[\d.]+|UNKNOWN|pending)/

      module_function

      def from(body)
        match = body.to_s.match(PATTERN)
        match ? match[1] : 'UNKNOWN'
      end
    end

    # Decides whether a canary run has the repository, model key, and token it needs.
    # The result names missing settings. It never copies secret values.
    module Preflight
      NAMES = {
        'SHAKA_CANARY_REPO' => 'vars.SHAKA_CANARY_REPO',
        'SHAKA_CANARY_MODEL_KEY' => 'secrets.SHAKA_CANARY_MODEL_KEY',
        'SHAKA_CANARY_TOKEN' => 'secrets.SHAKA_CANARY_TOKEN'
      }.freeze
      REPO = %r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z}

      module_function

      def decide(env)
        missing = NAMES.select { |key, _label| env[key].to_s.strip.empty? }.values
        return skip(missing) if missing.any?

        configured(env)
      end

      def skip(missing)
        notice = "Canary skipped: missing #{missing.join(', ')}. " \
                 'Set them, then rerun this workflow. Merging it is safe before setup.'
        { 'action' => 'skip', 'notice' => notice, 'keep' => Pulls::KEEP }
      end

      def configured(env)
        repo = env.fetch('SHAKA_CANARY_REPO').strip
        keep = keep_count(env)
        return invalid(repo, keep) unless repo.match?(REPO) && keep

        { 'action' => 'run', 'repo' => repo, 'keep' => keep }
      end

      def invalid(repo, keep)
        { 'action' => 'invalid', 'notice' => "Canary cannot start: #{invalid_detail(repo, keep)}.",
          'keep' => Pulls::KEEP }
      end

      def invalid_detail(repo, keep)
        return 'vars.SHAKA_CANARY_KEEP must be a positive integer' unless keep

        "vars.SHAKA_CANARY_REPO is #{repo.inspect}"
      end

      def keep_count(env)
        raw = env['SHAKA_CANARY_KEEP'].to_s.strip
        return Pulls::KEEP if raw.empty?

        value = Integer(raw, exception: false)
        value if value&.positive?
      end

      def write_output(result, path)
        lines = ["action=#{result.fetch('action')}", "keep=#{result.fetch('keep')}"]
        lines << "notice=#{result['notice']}" if result['notice']
        lines << "repo=#{result['repo']}" if result['repo']
        File.write(path, "#{lines.join("\n")}\n")
      end
    end
  end
end
