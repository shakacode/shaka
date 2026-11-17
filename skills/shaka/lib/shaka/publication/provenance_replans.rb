# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative 'managed_region'
require_relative 'provenance'
require_relative 'provenance_history'

module Shaka
  # Records why a PR's recommendation changed, in a marker of its own so a Shaka install that
  # predates it reads the provenance history unchanged and only drops these reasons.
  module ProvenanceReplans
    PREFIX = '<!-- shaka:replans '
    MARK = /#{Regexp.escape(PREFIX)}(.*?) -->/
    FIELDS = %w[entry reason].freeze
    # The latest replans a long-lived PR keeps; the newest one guards against a resent reason.
    RECENT = 20

    module_function

    # A fork author can edit the body, so a fork's replans are never carried, as with history.
    def recorded(pull)
      return [] unless pull && ProvenanceHistory.same_repository?(pull)

      previous(pull['body'])
    end

    # entry is the history row's position counting omitted rows, which truncation leaves stable.
    def carry(pull, entry, reason)
      replans = recorded(pull)
      return replans unless reason

      (replans + [{ 'entry' => entry, 'reason' => reason }]).last(RECENT)
    end

    # The reason for each retained history row, or nil.
    def row_reasons(history, replans)
      reasons = replans.to_h { |replan| replan.values_at('entry', 'reason') }
      history.fetch('entries').each_index.map do |index|
        reasons[index.zero? ? 0 : history.fetch('omitted') + index]
      end
    end

    def marker(replans) = (replans.empty? ? nil : "#{PREFIX}#{JSON.generate('replans' => replans)} -->")

    def previous(body)
      region = Publishing.managed_region(body).to_s
      openings = region.scan(PREFIX.strip).size
      return [] if openings.zero?

      json = region[MARK, 1]
      raise invalid unless openings == 1 && json

      validated(JSON.parse(json))
    rescue JSON::ParserError
      raise invalid
    end

    def validated(parsed)
      replans = parsed.is_a?(Hash) && parsed.keys == ['replans'] && parsed['replans']
      valid = replans.is_a?(Array) && replans.size.between?(1, RECENT) && replans.all? { |replan| valid?(replan) }
      raise invalid unless valid

      replans
    end

    def valid?(replan)
      replan.is_a?(Hash) && replan.keys.sort == FIELDS.sort && replan['entry'].is_a?(Integer) &&
        replan['entry'].positive? && ExecutionProvenance.reason?(replan['reason'])
    end

    def invalid
      Error.new('The PR body holds recommendation changes this helper did not write; ' \
                "restore or remove its #{PREFIX.strip} marker, then publish again.")
    end

    private_class_method :previous, :validated, :valid?, :invalid
  end
end
