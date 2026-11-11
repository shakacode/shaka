# frozen_string_literal: true

require_relative 'error'
require_relative 'ci_review_wait'
require_relative 'required_checks'
require_relative 'publication/managed_region'
require_relative 'publication/rendering_preview'
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

    # Refresh only the ready time in an existing description for the head being handed off.
    def refresh(github, gate, head:)
      return 'unchanged' unless gate

      path = "repos/#{github.repository}/pulls/#{github.number}"
      pull = github.api(path)
      return 'unchanged' unless open_head?(pull, head)

      body = pull['body']
      updated = refresh_body(body, github, gate, head)
      return 'unchanged' unless updated

      write_if_current(github, path, pull, updated)
    rescue Error
      'unavailable'
    end

    def write_if_current(github, path, pull, updated)
      current = github.api(path)
      return 'changed' unless open_head?(current, pull.dig('head', 'sha')) && current['body'] == pull['body']

      github.api(path, method: 'PATCH', fields: { body: updated })
      'updated'
    end

    def open_head?(pull, head) = pull['state'] == 'open' && pull.dig('head', 'sha') == head

    def refresh_body(body, github, gate, head)
      region = Publishing.managed_region(body)
      stats = ThroughputStats.read(region)
      return unless stats && stats['head'] == head && [nil, 'UNKNOWN'].include?(stats['t2'])

      ready = observed_at(github, gate)
      return unless ready.is_a?(Time)

      updated = ThroughputStats.update(region, 't2' => ready.utc.iso8601)
      body.sub("#{Publishing::OPEN_MARK}#{region}") { "#{Publishing::OPEN_MARK}#{RenderingPreview.invalidate(updated)}" }
    end

    def observed_at(github, gate)
      ThroughputStats.ready_at(github.check_times, required: required_names(github, gate),
                                                   review_jobs: gate[:jobs], wait: gate[:wait])
    end

    def required_names(github, gate)
      checks = RequiredChecks.new(github, seam_names: gate[:seam_required_checks]).call.fetch('checks')
      checks.filter_map { |row| row['name'] if row.is_a?(Hash) }
    end
  end
end
