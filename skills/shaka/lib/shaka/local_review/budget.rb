# frozen_string_literal: true

require_relative '../error'
require 'cgi'

module Shaka
  # A maintainer's absolute task limit survives retries and overlapping continuation prompts.
  class LocalReviewBudget
    def self.validate_options!(options)
      selected = options.values_at(:max_review_executions, :budget_reason)
      return if selected.all?(&:nil?)

      raise Error, '--max-review-executions and --budget-reason require --ledger' unless options[:ledger]

      limit, reason = selected
      raise Error, '--max-review-executions must be a positive integer' unless limit.to_s.match?(/\A[1-9]\d*\z/)
      raise Error, '--budget-reason must explain the maintainer authorization' unless
        valid_reason?(reason)
    end

    def self.valid_reason?(reason)
      reason.is_a?(String) && !reason.strip.empty? && reason.bytesize <= 2000 && !reason.match?(/[\r\n]/)
    end

    def self.notice(stored, completed:)
      return [] unless stored

      record = new(stored, completed:).record
      ["**Task review budget:** #{record['used']} of #{record['limit']} review starts, including failed launches. " \
       "#{CGI.escapeHTML(record['reason'])}"]
    end

    def initialize(stored, completed:, limit: nil, reason: nil)
      @record = stored || { 'limit' => limit, 'used' => completed, 'reason' => reason }
      validate!(completed)
      return unless limit

      raise Error, 'Task review budget cannot be lower than its consumed starts.' if limit < @record['used']

      @record = @record.merge('limit' => limit, 'reason' => reason)
    end

    attr_reader :record

    def limit = record.fetch('limit')

    def consume!
      if record.fetch('used') >= limit
        raise LocalReviewLedger::RoundCap,
              "Task review execution budget (#{limit}) reached; reassess before reviewing."
      end

      @record = record.merge('used' => record.fetch('used') + 1)
    end

    private

    def validate!(completed)
      return if valid_shape? && valid_counts?(completed) && self.class.valid_reason?(record['reason'])

      raise Error, 'Invalid task review budget; preserve the ledger and recover its recorded authorization.'
    end

    def valid_shape?
      record.is_a?(Hash) && record.keys.sort == %w[limit reason used] &&
        record['limit'].is_a?(Integer) && record['limit'].positive?
    end

    def valid_counts?(completed)
      record['used'].is_a?(Integer) && record['used'] >= completed && record['used'] <= record['limit']
    end
  end

  # Applies the recorded task limit without changing repository policy or losing spent slots.
  module LocalReviewLedgerBudget
    def max_rounds(default)
      return default unless data['task_budget']

      LocalReviewBudget.new(data['task_budget'], completed: rounds.size).limit
    end

    private

    def task_budget(base, selection)
      raise Error, 'Task review budget belongs to another base; preserve this ledger.' if
        data['task_budget'] && data['base'] != base
      return unless data['task_budget'] || selection

      LocalReviewBudget.new(data['task_budget'], completed: rounds.size, **(selection || {}))
    end

    def save_task_budget(base, budget)
      write(data.merge('base' => base, 'task_budget' => budget.record, 'local_max_rounds' => budget.limit)) if budget
    end
  end
end
