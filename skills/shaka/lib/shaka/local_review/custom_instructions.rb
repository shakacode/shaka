# frozen_string_literal: true

require_relative '../configuration'
require_relative '../repository_config'

module Shaka
  # Adds a repository's custom instructions after the trusted AGENTS.md criteria, whichever prompt applies.
  module LocalReviewCustomInstructions
    CONFIG = File.expand_path('../../../config', __dir__)
    # What each reviewer reads: its setting, and the packaged text that says what the instructions may override.
    SCOPES = {
      'review' => { label: 'review.custom_instructions_file', heading: 'REVIEW',
                    precedence: File.join(CONFIG, 'review-instructions-precedence.md') },
      'checkpoint' => { label: 'checkpoint.custom_instructions_file', heading: 'CHECKPOINT',
                        precedence: File.join(CONFIG, 'checkpoint-rules-precedence.md') }
    }.freeze

    private

    def custom_instructions_scope = 'review'

    def custom_instructions(marker)
      return '' unless settings_ref

      path, = custom_instructions_choice
      text = custom_instructions_text(path)
      return '' unless text

      @custom_instructions_source = path
      scope = SCOPES.fetch(custom_instructions_scope)
      label = "TRUSTED #{scope.fetch(:heading)} RULES #{marker}"
      precedence = File.read(scope.fetch(:precedence), encoding: 'UTF-8')
      "--- BEGIN #{label} FROM #{settings_ref}:#{path} ---\n#{precedence}\n#{text}\n--- END #{label} ---\n\n"
    end

    # Read like a configured prompt: the private tree for individual setup, otherwise the settings commit.
    # A file the settings name must exist; the default file is optional.
    def custom_instructions_text(path)
      _, named = custom_instructions_choice
      return private_custom_instructions(path, named) if individual_prompt?(path)

      access = { executable: git_executable, capture: method(:capture), resolver: method(:bounded_git) }
      return Configuration.prompt_at_commit(root:, ref: settings_ref, path:, git_access: access) if named

      Configuration.optional_prompt_at_commit(root:, ref: settings_ref, path:, git_access: access)
    end

    def private_custom_instructions(path, named)
      label = SCOPES.fetch(custom_instructions_scope).fetch(:label)
      named ? Configuration.private_prompt(root:, path:, label:) : Configuration.optional_private_prompt(root:, path:)
    end

    def custom_instructions_choice
      @custom_instructions_choice ||= begin
        review = effective_review || {}
        checkpoint = RepositoryConfig::PostImplementationSchema
        if custom_instructions_scope == 'checkpoint'
          checkpoint.custom_instructions(review.fetch(checkpoint::KEY, {}))
        else
          RepositoryConfig::PromptFiles.review_custom_instructions(review)
        end
      end
    end

    def prompt_source
      [super, @custom_instructions_source].compact.join(' + ')
    end
  end
end
