# frozen_string_literal: true

require 'yaml'
require_relative 'defaults'
require_relative 'error'
require_relative 'ci_review_wait'
require_relative 'merge_hold'
require_relative 'merge_limits'
require_relative 'merge_review_floor'
require_relative 'prose_limits'
require_relative 'configuration/paths'
require_relative 'configuration/layout'
require_relative 'repository_config/duplicate_keys'
require_relative 'repository_config/schema'
require_relative 'repository_config/prompt_files'

module Shaka
  # Loads the small, typed repository contract used by the workflow.
  class RepositoryConfig
    DEFAULT_WIP = Defaults.fetch('wip')
    DEFAULT_PR_DESCRIPTION = Defaults.fetch('pr_description').except('opening_check').freeze

    # base_branch is nil when the seam omits it, meaning the repository's default branch.
    attr_reader :base_branch, :commands, :review, :merge, :wip, :pr_description,
                :opening_check, :prose_limits, :project_guidance, :sha, :config_path

    def self.load(root: Dir.pwd, source: nil, available_commands: nil, sha: nil, candidate_commands: true,
                  &prompt_validator)
      new(root:, source:, available_commands:, sha:, candidate_commands:, &prompt_validator).load
    end

    def self.prompt_files(review:, opening:, guidance: {}) = PromptFiles.list(review:, opening:, guidance:)

    def initialize(root:, source: nil, available_commands: nil, sha: nil, candidate_commands: true,
                   &prompt_validator)
      if source && available_commands.nil?
        raise Error, 'available_commands is required when repository policy comes from another source'
      end

      @root = File.realpath(root)
      @source = source
      @available_commands = available_commands
      @sha = sha
      @candidate_commands = candidate_commands
      @prompt_validator = prompt_validator
      select_paths
    end

    def select_paths
      @layout = sha ? Configuration::Layout.commit(root: @root, sha:) : Configuration::Layout.worktree(root: @root)
      @candidate_detected = if @candidate_commands
                              sha ? Configuration::Layout.worktree(root: @root, allow_missing: true) : @layout
                            end
      @candidate_layout = @candidate_detected || @layout
      @selection = Configuration::Layout::Selection.new(policy: @layout, candidate: @candidate_layout)
      @config_path = @layout.contract
    end

    private :select_paths

    def load
      source = @source || File.read(File.join(@root, config_path), encoding: 'UTF-8')
      DuplicateKeys.check(source, filename: config_path)
      @data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      apply_schema
      self
    rescue Psych::Exception => e
      raise Error, "Invalid #{config_path}: #{e.message}"
    end

    def command(name)
      commands.fetch(name.to_s) { raise Error, "#{name} is not configured for this repository" }
    end

    # Callers read this as the effective contract, so defaults belong in it.
    def to_h
      @data.merge('commands' => commands, 'review' => review, 'merge' => merge, 'wip' => wip,
                  'paths' => { 'policy_configuration' => config_path,
                               'candidate_configuration' => @candidate_detected&.contract,
                               'trusted_command_directory' => @layout.command_directory,
                               'candidate_command_directory' => @candidate_layout.command_directory },
                  'opening_check' => opening_check, 'prose_limits' => prose_limits, 'pr_description' => pr_description)
    end

    # The settings exactly as config.yml states them, before any default applies.
    def explicit_settings = @data

    def prompt_files = self.class.prompt_files(review:, opening: opening_check, guidance: project_guidance)

    def warnings = PromptFiles.warnings(root: @root, sha:, review:)

    private

    def apply_schema
      schema = Schema.new(root: @root, data: @data, available_commands: @available_commands,
                          candidate_commands: @candidate_commands, selection: @selection,
                          &@prompt_validator)
      schema.validate
      @commands = schema.commands
      @opening_check = OpeningSchema.effective(schema.opening_check)
      assign_sections
    end

    def assign_sections
      @base_branch = @data['base_branch']
      @review = with_default_review_wait(PostImplementationSchema.fold(@data))
      merge = @data.fetch('merge')
      @merge = { 'auto_max_review_floor' => MergeReviewFloor::DEFAULT, 'hold_labels' => MergeHold::DEFAULT }
               .merge(merge, 'limits' => MergeLimits.new(merge.fetch('limits', {})).to_h)
      @wip = WipSchema.resolve(@data.fetch('wip', {}))
      assign_presentation
    end

    def assign_presentation
      @pr_description = DEFAULT_PR_DESCRIPTION.merge(@data.fetch('pr_description', {}).except('opening_check'))
      @prose_limits = ProseLimits.new(@data.fetch('prose_limits', {})).to_h
      @project_guidance = ProjectGuidanceSchema.resolve(@data)
    end

    def with_default_review_wait(review)
      { 'ci_review_wait' => CiReviewWait::DEFAULT, 'local_max_rounds' => ReviewLimit::DEFAULT,
        'startup_check' => Defaults.fetch('review', 'startup_check') }.merge(review)
    end
  end
end
