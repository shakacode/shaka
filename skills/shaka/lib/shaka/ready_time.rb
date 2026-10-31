# frozen_string_literal: true

require_relative 'error'
require_relative 'ci_review_wait'
require_relative 'required_checks'
require_relative 'publication/throughput_stats'

module Shaka
  # Reads when the current head's gate turned green, so a description update records it without a running watch.
  module ReadyTime
    module_function

    # Nil until trusted settings say which checks and reviews make up the gate.
    def gate(config)
      return unless config

      review = config.review
      { jobs: Array(review['ci_review_jobs']),
        wait: CiReviewWait.effective(seam: review['ci_review_wait'], override: nil),
        seam_required_checks: config.merge['required_checks'] }
    end

    # The time is a side record, so a failed read leaves it for the next update and publication continues.
    def attach(timeline, github, gate)
      return timeline unless gate

      ready = ThroughputStats.ready_at(github.check_times, required: required_names(github, gate),
                                                           review_jobs: gate[:jobs], wait: gate[:wait])
      ready.is_a?(Time) ? timeline.merge('ready_at' => ready) : timeline
    rescue Error
      timeline
    end

    def required_names(github, gate)
      checks = RequiredChecks.new(github, seam_names: gate[:seam_required_checks]).call.fetch('checks')
      checks.filter_map { |row| row['name'] if row.is_a?(Hash) }
    end
  end
end
