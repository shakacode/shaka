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
    FIELDS = %w[head recommended reason].freeze
    # The latest replans a long-lived PR keeps; the newest one guards against a resent reason.
    RECENT = 20

    module_function

    # A fork author can edit the body, so a fork's replans are never carried, as with history.
    def recorded(pull)
      return [] unless pull && ProvenanceHistory.same_repository?(pull)

      previous(pull['body'])
    end

    def carry(pull, recommended, reason)
      replans = recorded(pull)
      return replans unless reason

      (replans + [{ 'head' => pull.dig('head', 'sha'), 'recommended' => recommended, 'reason' => reason }])
        .last(RECENT)
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
      replan.is_a?(Hash) && replan.keys.sort == FIELDS.sort && replan['head'].to_s.match?(ProvenanceHistory::HEAD) &&
        ExecutionProvenance.reason?(replan['reason']) && route?(replan['recommended'])
    end

    def route?(route)
      parts = route.to_s.split(' / ', -1)
      parts.size == 2 && parts.all? { |part| part.match?(ExecutionProvenance::SAFE_VALUE) }
    end

    def invalid
      Error.new('The PR body holds recommendation changes this helper did not write; ' \
                "restore or remove its #{PREFIX.strip} marker, then publish again.")
    end

    private_class_method :previous, :validated, :valid?, :route?, :invalid
  end
end
