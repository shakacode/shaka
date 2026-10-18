# frozen_string_literal: true

require_relative 'error'
require_relative 'publication/text'
require_relative 'reviewer_selection'

module Shaka
  # review.provider_coverage names providers each change should get a review from. Coverage changes
  # no reviewer choice: it names each listed provider that did not review, with the reason, and
  # never blocks. Writing a change is not reviewing it, so the implementing provider gets no credit.
  module ReviewCoverage
    KEY = 'provider_coverage'
    NOT_LISTED = 'not listed in review.local_review_agents'
    NOT_CHOSEN = 'not chosen within review.local_review_count'
    UNAVAILABLE = ReviewerSelection::UNAVAILABLE
    NOT_SET_UP = ReviewerSelection::NOT_SET_UP
    # A reason can name a file on the reviewer's machine; a public PR must not show it.
    LOCAL_PATH = %r{(?<![\w./-])(?:~|/).*}m

    # Selection compares these with each reviewer's provider, folding case.
    def self.validate!(review)
      providers!(review[KEY]) if review.key?(KEY)
    end

    def self.providers!(providers)
      unless providers.is_a?(Array) && providers.all? { |provider| name?(provider) }
        raise Error, "review.#{KEY} must be a list of provider names such as openai"
      end

      repeated = providers.map(&:downcase).tally.find { |_, count| count > 1 }
      raise Error, "review.#{KEY} repeats #{repeated.first}" if repeated
    end

    def self.name?(value) = value.is_a?(String) && value.match?(%r{\A[^/\s]+\z})

    # Reads the `reviewers` run order and the `considered` reasons `ReviewerSelection` returns.
    def self.gaps(providers, selection)
      reviewed = selection.fetch('reviewers').map { |id| provider(id) }
      providers.map(&:downcase).uniq.reject { |name| reviewed.include?(name) }.map do |name|
        { 'provider' => name, 'reason' => reason(listed_reasons(selection, name)) }
      end
    end

    def self.listed_reasons(selection, name)
      listed = selection.fetch('considered').select { |entry| provider(entry.fetch('reviewer')) == name }
      listed.map { |entry| entry.fetch('reason') }
    end

    def self.reason(reasons)
      return NOT_LISTED if reasons.empty?
      return NOT_SET_UP if reasons.all?(NOT_SET_UP)

      reasons.all? { |why| [UNAVAILABLE, NOT_SET_UP].include?(why) } ? UNAVAILABLE : NOT_CHOSEN
    end

    # Renders the gaps copied from `shaka reviewer`; a provider in `reviewed` is not a gap.
    def self.notice(gaps, reviewed)
      gaps = PublicationText.list(gaps, 'coverage_gaps')
      return [] if gaps.empty?

      reviewed = reviewed.map { |id| provider(id) }
      ["**Review coverage gap:** #{gaps.map { |gap| gap_text(gap, reviewed) }.join(' ')}"]
    end

    def self.gap_text(gap, reviewed)
      raise Error, 'Each coverage gap must be an object.' unless gap.is_a?(Hash)

      name = PublicationText.single_line(gap['provider'], 'coverage gap provider').downcase
      raise Error, "Coverage gap for #{name} is wrong: #{name} reviewed this commit." if reviewed.include?(name)

      reason = PublicationText.single_line(gap['reason'], 'coverage gap reason').sub(LOCAL_PATH, '[path]')
      "no local review of this commit from `#{name}`: #{reason}."
    end

    def self.provider(id) = id.split('/').first.downcase
    private_class_method :providers!, :name?, :listed_reasons, :reason, :gap_text, :provider
  end
end
