# frozen_string_literal: true

# Loads trusted opening-check settings after publication and selects a reviewer.

require_relative 'opening_check'
require_relative 'reviewer_selection'
require_relative 'trusted_config_source'
require 'tmpdir'

module Shaka
  # Loads the opted-in parser choice after a PR description is published.
  class OpeningPublication
    def self.with_safe_path(root:, select_gh: true)
      original = ENV.fetch('PATH', nil)
      candidate_root = OpeningCheckout.root(root)
      raise Error, 'Candidate checkout root is unknown.' unless candidate_root

      ENV['PATH'] = LocalReviewPathGuard.safe_path(original.to_s, candidate_root:, drop_candidate: true,
                                                                  all_executables: true)
      gh = selected_gh(original.to_s, candidate_root) if select_gh
      return yield(candidate_root, gh) unless select_gh

      with_neutral_directory(candidate_root) { |neutral| yield candidate_root, gh, neutral }
    ensure
      ENV['PATH'] = original
    end

    def self.with_neutral_directory(candidate_root)
      Dir.mktmpdir('shaka-description-') do |neutral|
        raise Error, 'Temporary publication directory is inside candidate checkout.' if
          LocalReviewExecutable.candidate_owned?(File.realpath(neutral), candidate_root)

        yield neutral
      end
    end

    def self.selected_gh(original_path, candidate_root)
      gh = LocalReviewPathGuard.safe_executable(original_path, 'gh', candidate_root)
      return unless gh

      return gh unless LocalReviewPathGuard.shebang_interpreter(gh)

      linked = LocalReviewPathGuard.candidate_executable_link?(File.dirname(gh), candidate_root,
                                                               { all_executables: true })
      linked ? LocalReviewPathGuard.safe_executable(ENV.fetch('PATH'), 'gh', candidate_root) : gh
    end

    def initialize(root:, ref:, reviewer: nil, model: nil)
      @root = root
      @ref = ref
      @reviewer = reviewer
      @model = model
    end

    def call(summary)
      @prompt = nil
      raise Error, 'No trusted --ref supplied for opening settings.' unless @ref
      raise Error, 'Opening settings require a full commit SHA from the trusted default branch.' unless
        @ref.match?(/\A[0-9a-f]{40}\z/i)

      self.class.with_safe_path(root: @root, select_gh: false) do |candidate_root|
        check_with_trusted_settings(summary, candidate_root)
      end
    rescue StandardError => e
      fallback(summary, e, @prompt)
    end

    private

    def check_with_trusted_settings(summary, candidate_root)
      source = TrustedConfigSource.new(root: @root)
      config = TrustedConfigSource.from_ref(root: @root, ref: @ref)
      @prompt = source.opening_prompt(config) if config&.opening_check&.key?('prompt_file')
      validate_reviewer!(config) if @reviewer
      OpeningCheck.new(summary:, candidate_root:, reviewer: @reviewer, model: @model, prompt: @prompt).call
    end

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
