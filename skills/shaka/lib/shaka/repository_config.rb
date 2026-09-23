# frozen_string_literal: true

require 'yaml'
require_relative 'error'
require_relative 'repository_config/command_paths'
require_relative 'repository_config/duplicate_keys'
require_relative 'repository_config/schema'

module Shaka
  # Loads the small, typed repository contract used by the workflow.
  class RepositoryConfig
    PATH = '.agents/agent-workflow.yml'

    DEFAULT_RECOVERY = { 'publish_locations' => true }.freeze

    # base_branch is nil when the seam omits it, meaning the repository's default branch.
    attr_reader :base_branch, :commands, :review, :merge, :recovery, :sha

    def self.load(root: Dir.pwd, source: nil, available_commands: nil, sha: nil, candidate_commands: true)
      new(root:, source:, available_commands:, sha:, candidate_commands:).load
    end

    def initialize(root:, source: nil, available_commands: nil, sha: nil, candidate_commands: true)
      if source && available_commands.nil?
        raise Error, 'available_commands is required when repository policy comes from another source'
      end

      @root = File.realpath(root)
      @source = source
      @available_commands = available_commands
      @sha = sha
      @candidate_commands = candidate_commands
    end

    def load
      source = @source || File.read(File.join(@root, PATH), encoding: 'UTF-8')
      DuplicateKeys.check(source, filename: PATH)
      @data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      apply_schema
      self
    rescue Psych::Exception => e
      raise Error, "Invalid #{PATH}: #{e.message}"
    end

    def command(name)
      commands.fetch(name.to_s)
    end

    # Callers read this as the effective contract, so defaults belong in it.
    def to_h
      @data.merge('commands' => commands, 'review' => review, 'recovery' => recovery)
    end

    private

    def apply_schema
      schema = Schema.new(root: @root, data: @data, available_commands: @available_commands, sha: @sha,
                          candidate_commands: @candidate_commands)
      schema.validate
      @commands = schema.commands
      assign_sections
    end

    def assign_sections
      @base_branch = @data['base_branch']
      @review = with_default_review_wait(@data.fetch('review'))
      @merge = @data.fetch('merge')
      @recovery = DEFAULT_RECOVERY.merge(@data.fetch('recovery', {}))
    end

    def with_default_review_wait(review)
      { 'wait_for_all_ci_reviewers' => false }.merge(review)
    end
  end
end
