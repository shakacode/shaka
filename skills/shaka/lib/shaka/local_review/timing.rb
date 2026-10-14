# frozen_string_literal: true

require_relative '../call_log'

module Shaka
  # Retains timing without changing completion or reviewer-fallback rules.
  module LocalReviewTiming
    def run
      @attempted = false
      result, timing = CallLog.measure { with_requested_model(outcome) }
      timing['timeout_seconds'] = @options[:timeout_seconds] if @options[:timeout_seconds].is_a?(Integer)
      retain_attempt(keep_round(result.merge(timing)))
    ensure
      finish_ledger
    end

    private

    # Timing covers setup, invocation and report validation, before local evidence retention.
    def keep_round(result)
      record_round(result)
    rescue Shaka::Error, SystemCallError => e
      with_requested_model(setup_failure(e)).merge(result.slice('started_at', 'duration_ms', 'timeout_seconds'))
    end

    # A failed attempt never becomes a completed round. An unavailable ledger keeps timing
    # in the returned result and explicitly reports the retention gap without changing review status.
    def retain_attempt(result)
      return result unless @options[:ledger]

      LocalReviewBudget.validate_options!(@options)
      @ledger ||= LocalReviewLedger.new(@options[:ledger], root:)
      if !@started && File.exist?(@ledger.path)
        raise Shaka::Error, 'Review ledger did not authorize this start; preserve its history. Timing is in the result.'
      end

      @ledger.record_attempt!(result)
      result.merge('ledger' => @ledger.path, 'timing_retention' => 'retained')
    rescue Shaka::Error, SystemCallError, JSON::ParserError => e
      result.merge('timing_retention' => 'not_retained', 'timing_retention_reason' => e.message)
    end
  end

  # Compact attempt history lives in the same private ledger as completed rounds.
  module LocalReviewAttemptHistory
    # Keep attribution and terminal state, never prompt, report, diagnostic or error prose.
    ATTEMPT_FIELDS = %w[head reviewer status attempted failure_stage failure_cause started_at
                        duration_ms timeout_seconds requested_model requested_effort model prompt_source
                        criteria_ref coverage].freeze

    # Append under the same lock as rounds and triage, so simultaneous completions lose neither.
    # Attempts remain separate: they neither satisfy review nor count against the round bound.
    def record_attempt!(result)
      locked do
        attempts = data.fetch('attempts', [])
        raise Error, 'Review attempts must be a list.' unless attempts.is_a?(Array)

        attempt = result.slice(*ATTEMPT_FIELDS)
        attempt['attempted'] = result['status'] == 'completed' || result.fetch('attempted', false)
        write(data.merge('version' => LocalReviewBundle::VERSION, 'attempts' => attempts + [attempt]))
      end
    end
  end
end
