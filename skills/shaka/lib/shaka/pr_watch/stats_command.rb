# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../call_log'
require_relative '../github'
require_relative '../ci_review_wait'
require_relative '../status'
require_relative '../pr_watch'
require_relative '../trusted_config_source'

module Shaka
  class PrWatch
    # Records a pull request's ready and merge times once, without watching. A workflow runs it after a merge,
    # because nothing republishes the description after a GitHub merge click.
    module StatsCommand
      module_function

      def run(arguments)
        options = parse(arguments)
        return 0 if options[:help]
        raise Error, 'Expected OWNER/REPO NUMBER and --ref SHA.' unless arguments.length == 2 && options[:ref]

        CallLog.tag(repository: arguments[0], number: arguments[1])
        report(record(GitHub.new(*arguments), trusted_seam(options)))
      rescue OptionParser::ParseError, Error, SystemCallError, KeyError, JSON::ParserError, ArgumentError => e
        warn "shaka pr stats: #{e.message.gsub(/[\r\n]+/, ' ')}"
        1
      end

      # Reuses the watcher's writer. It changes only Shaka's stats: the stats block, the spend after the model line,
      # and the time after the estimated cost. It never carries one head's times to another.
      def record(github, seam)
        snapshot = Status.new(github, seam_required_checks: seam.merge&.fetch('required_checks', nil)).call
        publisher = publisher(github, snapshot.fetch('headRefOid'), seam.review)
        required, times = gate_evidence(github, snapshot)
        publisher.call(required:, times:)
        publisher.merged
        { 'head' => snapshot['headRefOid'], 'state' => snapshot['state'],
          'stats' => ThroughputStats.read(body(github)) }
      end

      # A merged pull request whose stats block still lacks the merge time fails the job, so the gap is visible.
      def report(result)
        puts JSON.generate(result)
        return 0 unless result['state'] == 'MERGED' && merge_unrecorded?(result['stats'])

        warn 'shaka pr stats: the merge time was not recorded.'
        1
      end

      def merge_unrecorded?(stats) = stats && [nil, 'UNKNOWN'].include?(stats['t3'])

      # Unreadable checks give no ready time, and the log says why. The writer still runs with no rows, so it moves a
      # block that named an earlier head to the merged head and marks a fork's carried ready time unverified. Only
      # these reads fall back: a failed write fails the job, which can be rerun.
      def gate_evidence(github, snapshot)
        rows = snapshot['requiredChecks']
        raise Error, snapshot['requiredChecksUnavailable'].to_s unless rows

        [rows.filter_map { |row| row['name'] if row.is_a?(Hash) }, github.check_times]
      rescue Error => e
        warn "shaka pr stats: no ready time recorded: #{e.message.gsub(/[\r\n]+/, ' ')}"
        [[], []]
      end

      def body(github) = github.api("repos/#{github.repository}/pulls/#{github.number}").fetch('body').to_s

      def publisher(github, head, review)
        ThroughputPublisher.new(github, head:, review_jobs: Array(review['ci_review_jobs']),
                                        wait: CiReviewWait.effective(seam: review['ci_review_wait']))
      end

      # The ready time follows the trusted review wait, so the command never runs without trusted settings.
      def trusted_seam(options)
        seam = TrustedConfigSource.from_ref(root: options[:root] || Dir.pwd, ref: options[:ref])
        raise Error, "No trusted Shaka settings at #{options[:ref]}." unless seam

        seam
      end

      def parse(arguments)
        options = {}
        OptionParser.new do |flags|
          flags.banner = 'Usage: shaka pr stats OWNER/REPO NUMBER --ref SHA [--root DIR]'
          %w[ref root].each { |name| flags.on("--#{name} VALUE") { |value| options[name.to_sym] = value } }
          flags.on('-h', '--help') do
            puts flags
            options[:help] = true
          end
        end.parse!(arguments)
        options
      end
    end
  end
end
