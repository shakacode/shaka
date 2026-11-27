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
        puts JSON.generate(record(GitHub.new(*arguments), trusted_seam(options)))
        0
      rescue OptionParser::ParseError, Error, SystemCallError, KeyError, JSON::ParserError => e
        warn "shaka pr stats: #{e.message.gsub(/[\r\n]+/, ' ')}"
        1
      end

      # Reuses the watcher's writer, which edits only an existing stats block and never carries one head's times
      # to another.
      def record(github, seam)
        snapshot = Status.new(github, seam_required_checks: seam.merge&.fetch('required_checks', nil)).call
        publisher = publisher(github, snapshot.fetch('headRefOid'), seam.review)
        required = required_names(snapshot['requiredChecks'])
        publisher.call(required:) if required
        publisher.merged
        { 'head' => snapshot['headRefOid'], 'state' => snapshot['state'],
          'stats' => ThroughputStats.read(body(github)) }
      end

      # Nil when GitHub could not report the required checks, so no ready time is guessed.
      def required_names(rows) = rows&.filter_map { |row| row['name'] if row.is_a?(Hash) }
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
