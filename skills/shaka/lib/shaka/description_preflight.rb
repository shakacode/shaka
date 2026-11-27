# frozen_string_literal: true

require_relative 'publication/intent_verification'
require_relative 'publication/provenance'
require_relative 'publication/skills_used'
require_relative 'publication/text'
require_relative 'usage/publisher_attribution'

module Shaka
  # Groups common description input errors before looking up the pull request.
  class DescriptionPreflight
    def initialize(content)
      @content = content
      @problems = []
    end

    def call
      prepared = check { prepare_identity }
      check { ExecutionProvenance.new(@content['provenance']).check_task_source! }
      check { IntentVerification.checks_for(@content) }
      check { SkillsUsed.new(@content['skills_used']).detail }
      return prepared if @problems.empty?

      raise Error, "Description input needs changes:\n- #{@problems.join("\n- ")}"
    end

    private

    def prepare_identity
      prepared = PublisherAttribution.prepare(@content)
      PublicationText.publisher_identity(prepared)
      prepared
    end

    def check
      yield
    rescue Error => e
      @problems << e.message
      nil
    end
  end
end
