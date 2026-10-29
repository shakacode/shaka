# frozen_string_literal: true

require_relative 'validation'
require_relative '../defaults'
require_relative '../reviewer_selection'

module Shaka
  class RepositoryConfig
    # Execution choices for product validation, separate from technical review.
    class PostImplementationSchema
      include Validation

      KEY = 'post_implementation'
      SECTION = 'checkpoint'
      REPLACEMENT = 'replacement_prompt_file'
      CUSTOM = 'custom_instructions_file'
      KEYS = ['enabled', 'reviewer', 'model', 'effort', REPLACEMENT, CUSTOM].freeze
      EFFORTS = { 'openai/codex' => %w[low medium high xhigh max],
                  'anthropic/claude' => %w[low medium high xhigh max],
                  'xai/grok' => %w[low medium high] }.freeze
      DEFAULTS = Defaults.fetch(SECTION)
      MOVED = "review.#{KEY} moved to the top-level #{SECTION} section".freeze

      def self.reviewer(identity) = ReviewerSelection.parse(identity).values.map(&:downcase).join('/')

      # Internal readers keep finding the checkpoint under review; settings write it only as `checkpoint`.
      def self.fold(data)
        review = data.is_a?(Hash) && data['review'].is_a?(Hash) ? data['review'] : {}
        if review.key?(KEY)
          raise Error, "#{MOVED}. Tell your agent: " \
                       '"Move review.post_implementation to checkpoint in the Shaka settings."'
        end
        return review unless data.is_a?(Hash) && data.key?(SECTION)

        review.merge(KEY => data[SECTION])
      end

      # The settings a checkpoint runs with: packaged defaults, then the repository's, then this task's. The
      # default model belongs to the default reviewer, so another reviewer chosen without a model drops it.
      def self.effective(settings, overrides = {})
        choices = DEFAULTS.merge(settings).merge(overrides)
        choices['reviewer'] = reviewer(choices.fetch('reviewer'))
        choices.delete('model') if discard_model?(settings, choices, overrides)
        choices
      end

      def self.discard_model?(settings, choices, overrides)
        return false if overrides.key?('model')
        return true if choices['reviewer'] != reviewer(settings.fetch('reviewer', DEFAULTS.fetch('reviewer')))

        choices['reviewer'] != DEFAULTS.fetch('reviewer') && !settings.key?('model')
      end
      private_class_method :discard_model?

      # The custom instructions' path, and whether settings named it; a named file must exist, the default need not.
      def self.custom_instructions(settings) = [settings.fetch(CUSTOM, DEFAULTS.fetch(CUSTOM)), settings.key?(CUSTOM)]

      def initialize(settings, label: SECTION)
        @settings = settings
        @label = label
      end

      def validate
        label = @label
        mapping!(@settings, label)
        renamed_prompt_file!(@settings, label)
        keys!(@settings, [], KEYS, label)
        validate_enabled(label)
        reviewer = self.class.reviewer(@settings.fetch('reviewer', DEFAULTS.fetch('reviewer')))
        raise Error, "#{label}.reviewer must be a supported provider/family" unless EFFORTS.key?(reviewer)

        validate_choices(label, reviewer)
        prompt_paths!(@settings, [REPLACEMENT, CUSTOM], label)
      end

      private

      def validate_enabled(label)
        return unless @settings.key?('enabled')
        return if [true, false].include?(@settings['enabled'])

        raise Error, "#{label}.enabled must be true or false"
      end

      def validate_choices(label, reviewer)
        ReviewSchema.model_name!(@settings['model'], "#{label}.model") if @settings.key?('model')
        return unless @settings.key?('effort')
        return if EFFORTS.fetch(reviewer).include?(@settings['effort'])

        raise Error, "#{label}.effort must be #{EFFORTS.fetch(reviewer).join(', ')} for #{reviewer}"
      end
    end
  end
end
