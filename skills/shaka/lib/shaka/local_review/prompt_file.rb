# frozen_string_literal: true

require_relative '../configuration'
require_relative '../configuration/machine_reviewers'
require_relative '../review_prompt'
require_relative '../reviewer_settings'
require_relative 'settings_source'

module Shaka
  # Reads the repository's review instructions from the same trusted commit as its criteria.
  module LocalReviewPromptFile
    include LocalReviewSettingsSource

    private

    # The heading, instructions, and fixed rules; a configured file replaces only the instructions.
    def review_instructions
      text = trusted_prompt_text
      ReviewPrompt.sections({ head:, base: @options[:base], reviewer:, effort: },
                            instructions: text, source: (replacement_label if text))
    end

    def replacement_label
      where = @private_prompt ? ' (individual settings, private)' : "@#{settings_ref}"
      setting, path = @replacement
      "replacement #{path}#{where} (#{setting})"
    end

    # Effective model and effort apply where the task named none; this machine's list fills what
    # the repository entry leaves unset.
    def apply_trusted_settings!
      agent = reviewer_settings(effective_review || {})
      apply_repository_settings!(agent) if agent
      machine = Configuration::MachineReviewers.load(home: Dir.home)
      machine&.fill(agent, reviewer)&.each { |key, value| @options[key.to_sym] ||= value }
    end

    def apply_repository_settings!(agent)
      schema = RepositoryConfig::ReviewSchema
      { model: [schema::MODEL, :model_name!], effort: [schema::EFFORT, :effort_level!] }
        .each do |option, (key, check)|
          next if @options[option] || !agent.key?(key)

          # This read skips the schema, so a bad value must fail here as setup, not later in the CLI.
          schema.public_send(check, agent[key], "review.local_review_agents #{key}")
          @options[option] = agent[key]
        end
    end

    def apply_reviewer_settings!
      apply_trusted_settings!
      validate_model!
      @config_notices = ReviewerSettings.notices(reviewer, model: @options[:model], effort: @options[:effort])
      ReviewerSettings.refuse!(@config_notices)
    end

    def trusted_prompt_text
      review = effective_review
      return unless review

      path = configured_prompt_path(review)
      path && configured_prompt(path, "review #{RepositoryConfig::ReviewSchema::PROMPT_FILE}")
    end

    # Individual setup keeps its own instructions in its untracked settings directory. Any other
    # path is read at the settings commit, so a branch cannot supply its own instructions.
    def configured_prompt(path, label)
      @private_prompt = individual_prompt?(path)
      return Configuration.private_prompt(root:, path:, label:) if @private_prompt

      access = { executable: git_executable, capture: method(:capture), resolver: method(:bounded_git) }
      Configuration.prompt_at_commit(root:, ref: settings_ref, path:, git_access: access)
    end

    def individual_prompt?(path)
      @individual_review && Configuration::PrivateInventory.private_path?(root:, path:)
    end

    # Runs the vetted Git under the review timeout, for this module and TrustedPathResolver.
    def bounded_git(*arguments)
      timeout = @options.fetch(:timeout_seconds)
      result = LocalReviewProcess.capture([git_executable, *arguments], stdin_data: nil, chdir: root, timeout:)
      status = result.last
      raise Shaka::Error, "git timed out after #{timeout}s" unless status
      raise Shaka::Error, 'git output drain timed out after 2s' if status.is_a?(LocalReviewProcess::DrainTimeout)

      result
    end

    # A reviewer's own file wins over the repository-wide one.
    def configured_prompt_path(review)
      prompt_file = RepositoryConfig::ReviewSchema::PROMPT_FILE
      agent = reviewer_settings(review)
      # This path reads the review section without the schema, so the old name must not be ignored.
      RepositoryConfig::ReviewSchema.renamed!(review)
      RepositoryConfig::ReviewSchema.renamed_agent_prompt_files!(review)
      owner, path = agent&.key?(prompt_file) ? ["#{reviewer} ", agent[prompt_file]] : ['review.', review[prompt_file]]
      return if path.nil?
      raise Shaka::Error, "review #{prompt_file} must be a repository path" unless path.is_a?(String)

      @replacement = ["#{owner}#{prompt_file}", path]
      @prompt_source = @replacement.join(' ')
      path
    end

    def reviewer_settings(review)
      agents = Array(review[RepositoryConfig::ReviewSchema::LOCAL_REVIEW_AGENTS]).grep(Hash)
      agents.find { |entry| entry.values_at(*ReviewerSelection::IDENTITY).join('/').downcase == reviewer }
    end

    # Names the instructions the reviewer received, for the published review summary.
    def prompt_source
      return 'Local settings preview (private source)' if @prompt_source && settings_ref != @options[:criteria_ref]
      return 'Individual settings (private source)' if @private_prompt

      @prompt_source || 'Shaka default'
    end
  end
end
