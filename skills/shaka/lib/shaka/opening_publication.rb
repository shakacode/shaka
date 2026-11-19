# frozen_string_literal: true

# Loads effective opening-check settings after publication and selects a reviewer.

require_relative 'opening_check'
require_relative 'reviewer_selection'
require_relative 'configuration'
require 'tmpdir'

module Shaka
  # Reads the opening settings and any replacement instructions the check uses, from the trusted commit.
  module OpeningPromptSettings
    # What the opening reviewer would read for `opening`, or nil when the check is disabled.
    def prompt_sections(opening, prose: nil)
      validate_ref!
      self.class.with_safe_path(root: @root, select_gh: false) do
        config = settings
        OpeningCheck.prompt_sections(opening, prompt: @prompt, source: @prompt_source, prose:) if
          config.opening_check.fetch('enabled')
      end
    end

    private

    def validate_ref!
      raise Error, 'No trusted --ref supplied for opening settings.' unless @ref
      raise Error, 'Opening settings require a full commit SHA from the trusted default branch.' unless
        @ref.match?(/\A[0-9a-f]{40}\z/i)
    end

    # Loads the settings and any replacement instructions the check reads.
    def settings
      config = Configuration.resolve_source(root: @root, ref: @ref, candidate_commands: false).first
      key = RepositoryConfig::ReviewSchema::PROMPT_FILE
      path = config.opening_check[key]
      if config.opening_check.fetch('enabled') && path
        @prompt = Configuration.opening_prompt(root: @root, config:, ref: @ref)
        private_copy = !config.sha && Configuration::PrivateInventory.private_path?(root: @root, path:)
        where = private_copy ? ' (individual settings, private)' : "@#{config.sha || @ref}"
        @prompt_source = "replacement #{path}#{where} (pr_description.opening_check.#{key})"
      end
      config
    end
  end

  # Loads the private or trusted team parser choice after a PR description is published.
  class OpeningPublication
    include OpeningPromptSettings

    def self.with_safe_path(root:, select_gh: true)
      original = ENV.fetch('PATH', nil)
      candidate_root = OpeningCheckout.root(root) || (raise Error, 'Candidate checkout root is unknown.')

      ENV['PATH'] = LocalReviewPathGuard.safe_path(original.to_s, candidate_root:, drop_candidate: true)
      gh = selected_command(select_gh, original.to_s, candidate_root)
      with_neutral_directory(candidate_root) do |neutral|
        in_context(select_gh, neutral) { yield candidate_root, gh, neutral }
      end
    ensure
      ENV['PATH'] = original
    end

    def self.in_context(select_gh, neutral, &)
      select_gh ? yield : Dir.chdir(neutral, &)
    end

    def self.selected_command(select_gh, original_path, candidate_root)
      return selected_gh(original_path, candidate_root) if select_gh

      LocalReviewPathGuard.safe_executable(ENV.fetch('PATH'), 'git', candidate_root)
      nil
    end

    def self.with_neutral_directory(candidate_root)
      Dir.mktmpdir('shaka-description-') do |neutral|
        raise Error, 'Temporary publication directory is inside candidate checkout.' if
          LocalReviewExecutable.candidate_owned?(File.realpath(neutral), candidate_root)

        yield neutral
      end
    end

    def self.selected_gh(original_path, candidate_root)
      # Reject malformed gh wrappers before a contaminated PATH directory is removed.
      original = LocalReviewPathGuard.first_executable(original_path.split(File::PATH_SEPARATOR, -1), 'gh',
                                                       candidate_root, true)
      LocalReviewPathGuard.interpreter_name(original, 'gh', candidate_root) if original
      LocalReviewPathGuard.safe_executable(ENV.fetch('PATH'), 'gh', candidate_root)
    end

    def initialize(root:, ref:, reviewer: nil, model: nil, effort: nil)
      @root = OpeningCheckout.root(root) || root
      @ref = ref
      @reviewer = reviewer
      @model = model
      @effort = effort
    end

    # A description also passes its visible prose; a walkthrough checks its opening alone.
    def call(summary, prose: nil)
      @prompt = nil
      @prose = prose
      validate_ref!

      self.class.with_safe_path(root: @root, select_gh: false) do |candidate_root|
        check_with_settings(summary, candidate_root)
      end
    rescue StandardError => e
      fallback(summary, e, @prompt)
    end

    private

    def check_with_settings(summary, candidate_root)
      config = settings
      return { 'status' => 'disabled' } unless config.opening_check.fetch('enabled')

      select_reviewer(config.opening_check)
      validate_reviewer!(config) if @reviewer
      OpeningCheck.new(summary:, candidate_root:, reviewer: @reviewer, model: @model,
                       effort: @effort, prompt: @prompt, prose: @prose).call
    end

    def select_reviewer(settings)
      configured = settings['reviewer']
      same_reviewer = same_reviewer?(configured)
      @reviewer ||= configured
      @model ||= settings['model'] if same_reviewer
      @effort ||= same_reviewer ? settings['effort'] : RepositoryConfig::OpeningSchema::DEFAULTS.fetch('effort')
      @reviewer
    end

    def normalized(identity) = ReviewerSelection.parse(identity).values.map(&:downcase).join('/')

    def same_reviewer?(configured)
      !@reviewer || !configured || normalized(@reviewer) == normalized(configured)
    end

    def validate_reviewer!(config)
      requested = normalized(@reviewer)
      unless allowed_reviewers(config).any? { |identity| normalized(identity) == requested }
        raise Error, 'Opening reviewer is not configured for this repository.'
      end

      raise Error, 'Unsupported local reviewer' unless ReviewerSelection::SUPPORTED_REVIEWERS.include?(requested)

      @reviewer = requested
    end

    def allowed_reviewers(config)
      agents = Array(config.review[RepositoryConfig::ReviewSchema::LOCAL_REVIEW_AGENTS])
      identities = agents.map { |entry| entry.values_at('provider', 'model_family').join('/') }
      identities.push(config.opening_check['reviewer']).compact
    end

    def fallback(summary, error, prompt)
      result = OpeningCheck.new(summary:, candidate_root: OpeningCheckout.root(@root), prompt:, prose: @prose).call
      result.merge('reason' => "Opening check unavailable: #{error.message}")
    end
  end
end
