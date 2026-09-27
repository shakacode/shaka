# frozen_string_literal: true

require_relative 'opening_check'
require_relative 'reviewer_selection'
require_relative 'trusted_config_source'

module Shaka
  # Selects an opted-in opening parser; any setup failure leaves the host-model check available.
  class OpeningPublication
    def initialize(root:, ref:, reviewer: nil, model: nil)
      @root = root
      @ref = ref
      @reviewer = reviewer
      @model = model
    end

    def call(summary)
      raise Error, 'No trusted --ref supplied for opening settings.' unless @ref

      source = TrustedConfigSource.new(root: @root)
      config = TrustedConfigSource.from_ref(root: @root, ref: @ref)
      prompt = source.opening_prompt(config) if config&.opening_check&.key?('prompt_file')
      validate_reviewer!(config) if @reviewer
      OpeningCheck.new(summary:, candidate_root: OpeningCheckout.root(@root),
                       reviewer: @reviewer, model: @model, prompt:).call
    rescue StandardError => e
      fallback(summary, e, prompt)
    end

    private

    def validate_reviewer!(config)
      raise Error, 'Opening reviewer requires trusted opening_check.enabled.' unless
        config&.opening_check&.fetch('enabled', false)

      allowed = Array(config.review[RepositoryConfig::ReviewSchema::LOCAL_REVIEW_AGENTS])
      requested = ReviewerSelection.parse(@reviewer).values_at('provider', 'model_family').map(&:downcase)
      raise Error, 'Opening reviewer is not in the trusted reviewer list.' unless listed?(allowed, requested)

      normalized = requested.join('/')
      raise Error, 'Unsupported local reviewer' unless ReviewerSelection::SUPPORTED_REVIEWERS.include?(normalized)

      @reviewer = normalized
    end

    def listed?(allowed, requested)
      allowed.any? { |entry| entry.values_at('provider', 'model_family').map(&:downcase) == requested }
    end

    def fallback(summary, error, prompt)
      result = OpeningCheck.new(summary:, candidate_root: OpeningCheckout.root(@root), prompt:).call
      result.merge('reason' => "Opening check unavailable: #{error.message}")
    end
  end
end
