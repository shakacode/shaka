# frozen_string_literal: true

require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the optional repository guidance files the agent reads at named workflow phases.
    class ProjectGuidanceSchema
      include Validation

      KEY = 'project_guidance'
      NAMES = %w[pr_evidence merge_readiness].freeze

      def self.prompt_files(guidance)
        NAMES.filter_map { |name| ["#{KEY}.#{name}", guidance[name]] if guidance[name] }
      end

      def initialize(guidance) = @guidance = guidance

      def validate
        mapping!(@guidance, KEY)
        keys!(@guidance, [], NAMES, KEY)
        @guidance.each { |name, path| prompt_path!(path, "#{KEY}.#{name}") }
      end
    end
  end
end
