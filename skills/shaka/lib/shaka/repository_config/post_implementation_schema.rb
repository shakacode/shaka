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
      EXTRA = 'extra_prompt_file'
      KEYS = ['enabled', 'reviewer', 'model', 'effort', 'prompt_file', EXTRA].freeze
      EFFORTS = { 'openai/codex' => %w[low medium high xhigh max],
                  'anthropic/claude' => %w[low medium high xhigh max],
                  'xai/grok' => %w[low medium high] }.freeze
      DEFAULTS = Defaults.fetch(SECTION)

      def self.reviewer(identity) = ReviewerSelection.parse(identity).values.map(&:downcase).join('/')

      # Internal readers keep finding the checkpoint under review; settings write it only as `checkpoint`.
      def self.fold(data)
        review = data.is_a?(Hash) && data['review'].is_a?(Hash) ? data['review'] : {}
        raise Error, "review.#{KEY} moved to the top-level #{SECTION} section" if review.key?(KEY)
        return review unless data.is_a?(Hash) && data.key?(SECTION)

        review.merge(KEY => data[SECTION])
      end

      # The added file's path, and whether settings named it; a named file must exist, the default need not.
      def self.extra_prompt(settings) = [settings.fetch(EXTRA, DEFAULTS.fetch(EXTRA)), settings.key?(EXTRA)]

      def initialize(settings, label: SECTION)
        @settings = settings
        @label = label
      end

      def validate
        label = @label
        mapping!(@settings, label)
        keys!(@settings, [], KEYS, label)
        validate_enabled(label)
        reviewer = self.class.reviewer(@settings.fetch('reviewer', DEFAULTS.fetch('reviewer')))
        raise Error, "#{label}.reviewer must be a supported provider/family" unless EFFORTS.key?(reviewer)

        validate_choices(label, reviewer)
        %w[prompt_file extra_prompt_file].each do |key|
          prompt_path!(@settings[key], "#{label}.#{key}") if @settings.key?(key)
        end
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
