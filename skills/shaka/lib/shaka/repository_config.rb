# frozen_string_literal: true

require 'yaml'
require_relative 'error'
require_relative 'repository_config/duplicate_keys'
require_relative 'repository_config/recovery_schema'
require_relative 'repository_config/schema'

module Shaka
  # Loads the small, typed repository contract used by the workflow.
  class RepositoryConfig
    PATH = '.agents/agent-workflow.yml'

    DEFAULT_RECOVERY = { 'workspace_path' => true, 'snapshot' => true }.freeze

    attr_reader :base_branch, :commands, :review, :merge, :protection, :recovery

    def self.load(root: Dir.pwd, source: nil)
      new(root:, source:).load
    end

    # A seam read from another checkout answers only the recovery question, so only that
    # section is validated: its command paths describe the repository it came from.
    def self.recovery_from(source)
      data = parse(source)
      return DEFAULT_RECOVERY unless data.key?('recovery')

      RecoverySchema.new(data['recovery']).validate
      DEFAULT_RECOVERY.merge(data['recovery'])
    end

    def self.parse(source)
      DuplicateKeys.check(source, filename: PATH)
      data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      raise Error, "Invalid #{PATH}: it must be a mapping" unless data.is_a?(Hash)

      data
    rescue Psych::Exception => e
      raise Error, "Invalid #{PATH}: #{e.message}"
    end

    def initialize(root:, source: nil)
      @root = File.realpath(root)
      @source = source
    end

    def load
      @data = self.class.parse(@source || File.read(File.join(@root, PATH), encoding: 'UTF-8'))
      Schema.new(root: @root, data: @data).validate
      assign_sections
      self
    end

    def command(name)
      commands.fetch(name.to_s)
    end

    # Callers read this as the effective contract, so defaults belong in it.
    def to_h
      @data.merge('recovery' => recovery)
    end

    private

    def assign_sections
      @base_branch = @data.fetch('base_branch')
      @commands = @data.fetch('commands')
      @review = @data.fetch('review')
      @merge = @data.fetch('merge')
      @protection = @data.fetch('protection')
      @recovery = DEFAULT_RECOVERY.merge(@data.fetch('recovery', {}))
    end
  end
end
