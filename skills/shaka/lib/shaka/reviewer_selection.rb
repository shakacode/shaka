# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Chooses the reviewer that satisfies the alternate-review gate.
  #
  # The gate has one invariant: a reviewer's model family must not have produced any part of the
  # change. A differing provider is the preference layered on top of it. Both sets are derived here
  # from the same implementer identities, which is what stops a provider being compared against a
  # model family; stating the rule in prose twice is what let that happen before.
  class ReviewerSelection
    IDENTITY = %w[provider model_family].freeze
    ELIGIBLE = 'eligible'
    UNAVAILABLE = 'unavailable'
    FAMILY_CONTRIBUTED = 'model family contributed'
    PROVIDER_CONTRIBUTED = 'provider contributed'

    def self.parse(text)
      provider, family, extra = text.to_s.split('/')
      parts = [provider, family]
      valid = extra.nil? && parts.all? { |part| part.is_a?(String) && !part.strip.empty? }
      raise Error, "Reviewer identity must be PROVIDER/MODEL_FAMILY: #{text}" unless valid

      { 'provider' => provider.strip, 'model_family' => family.strip }
    end

    def initialize(reviewers:, implementers:, unavailable: [])
      @reviewers = reviewers || []
      @implementers = implementers
      @unavailable = unavailable
    end

    def call
      raise Error, 'At least one implementer identity is required.' if @implementers.empty?

      reasons = @reviewers.map { |entry| [entry, reason(entry)] }
      selected = pick(reasons)
      verdict(selected, reasons)
    end

    private

    # A same-provider reviewer is the floor, so it is only chosen once no eligible entry remains.
    def pick(reasons)
      [ELIGIBLE, PROVIDER_CONTRIBUTED].each do |wanted|
        found = reasons.find { |_, why| why == wanted }
        return found.first if found
      end
      nil
    end

    def reason(entry)
      return UNAVAILABLE if unavailable?(entry)
      return FAMILY_CONTRIBUTED if families.include?(entry['model_family'])
      return PROVIDER_CONTRIBUTED if providers.include?(entry['provider'])

      ELIGIBLE
    end

    def verdict(selected, reasons)
      outcome = outcome_for(selected, reasons)
      {
        'outcome' => outcome,
        'reviewer' => selected && identity(selected),
        'contributing_providers' => providers,
        'contributing_families' => families,
        'considered' => reasons.map { |entry, why| { 'reviewer' => identity(entry), 'reason' => why } },
        'note' => note(outcome, selected)
      }
    end

    def outcome_for(selected, reasons)
      return 'outside_list' unless selected
      return 'alternate' if reasons.assoc(selected).last == ELIGIBLE

      'same_provider'
    end

    def note(outcome, selected)
      case outcome
      when 'alternate' then "#{identity(selected)} satisfies the alternate-review gate."
      when 'same_provider'
        "#{identity(selected)} is the same-provider floor; label the review same-provider."
      else
        'No listed reviewer qualifies. Obtain an authorized reviewer outside the list, which ' \
        'never replaces a required named gate, and report a blocker only when none is reachable.'
      end
    end

    # Compare the components, never the joined string: "openai/foo"/"codex" and
    # "openai"/"foo/codex" render alike and are different identities.
    def unavailable?(entry)
      @unavailable.any? { |blocked| blocked.values_at(*IDENTITY) == entry.values_at(*IDENTITY) }
    end

    def families = @families ||= @implementers.map { |entry| entry['model_family'] }.uniq

    def providers = @providers ||= @implementers.map { |entry| entry['provider'] }.uniq

    # Display only; selection never keys on this string.
    def identity(entry) = entry.values_at(*IDENTITY).join('/')
  end
end
