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
      KEYS = ['reviewer', 'model', 'effort', REPLACEMENT, CUSTOM].freeze
      REMOVED = 'was removed; every repository runs the checkpoint. Tell your agent: ' \
                '"Remove checkpoint.enabled. Opt out of one task with post-implementation run --opt-out REASON."'
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
        refuse_enabled!(label)
        keys!(@settings, [], KEYS, label)
        reviewer = self.class.reviewer(@settings.fetch('reviewer', DEFAULTS.fetch('reviewer')))
        raise Error, "#{label}.reviewer must be a supported provider/family" unless EFFORTS.key?(reviewer)

        validate_choices(label, reviewer)
        prompt_paths!(@settings, [REPLACEMENT, CUSTOM], label)
      end

      private

      def refuse_enabled!(label)
        return unless @settings.key?('enabled')

        raise Error, "#{label}.enabled #{REMOVED}"
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
