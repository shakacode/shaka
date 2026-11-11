# frozen_string_literal: true

require_relative 'error'
require_relative 'ci_review_wait'
require_relative 'required_checks'
require_relative 'publication/managed_region'
require_relative 'publication/throughput_stats'

module Shaka
  # Reads when the current head's gate turned green, without requiring a running watch.
  module ReadyTime
    module_function

    # Nil until trusted settings say which checks and reviews make up the gate. A task override may only raise the wait.
    def gate(config, override: nil)
      return unless config

      review = config.review
      { jobs: Array(review['ci_review_jobs']),
        wait: CiReviewWait.effective(seam: review['ci_review_wait'], override:),
        seam_required_checks: config.merge['required_checks'] }
    end

    # The time is a side record, so a failed read leaves it for the next update and publication continues.
    def attach(timeline, github, gate)
      return timeline unless gate

      ready = observed_at(github, gate)
      ready.is_a?(Time) ? timeline.merge('ready_at' => ready) : timeline
    rescue Error
      timeline
    end

    # Use the normal description publisher when a known ready time is missing from this head's stats.
    def verify_fresh!(github, gate, head:, required:)
      return unless gate && stale?(github, gate, head:, required:)

      raise Error, 'Republish the PR description after CI completes to record ready time, then retry.'
    end

    def stale?(github, gate, head:, required:)
      pull = github.api("repos/#{github.repository}/pulls/#{github.number}")
      stats = ThroughputStats.read(Publishing.managed_region(pull['body']))
      return false unless stats && stats['head'] == head && [nil, 'UNKNOWN'].include?(stats['t2'])

      observed_at(github, gate, required:).is_a?(Time)
    rescue Error
      false
    end

    def observed_at(github, gate, required: required_names(github, gate))
      ThroughputStats.ready_at(github.check_times, required:, review_jobs: gate[:jobs], wait: gate[:wait])
    end

    def required_names(github, gate)
      checks = RequiredChecks.new(github, seam_names: gate[:seam_required_checks]).call.fetch('checks')
      checks.filter_map { |row| row['name'] if row.is_a?(Hash) }
    end
  end
end
