# frozen_string_literal: true

require 'yaml'
require_relative 'error'
require_relative 'repository_config/duplicate_keys'
require_relative 'repository_config/schema'

module Shaka
  # Loads the small, typed repository contract used by the workflow.
  class RepositoryConfig
    PATH = '.agents/agent-workflow.yml'

    attr_reader :base_branch, :commands, :review, :merge

    def self.load(root: Dir.pwd, source: nil)
      new(root:, source:).load
    end

    def initialize(root:, source: nil)
      @root = File.realpath(root)
      @source = source
    end

    def load
      source = @source || File.read(File.join(@root, PATH), encoding: 'UTF-8')
      DuplicateKeys.check(source, filename: PATH)
      @data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      Schema.new(root: @root, data: @data).validate
      assign_sections
      self
    rescue Psych::Exception => e
      raise Error, "Invalid #{PATH}: #{e.message}"
    end

    def command(name)
      commands.fetch(name.to_s)
    end

    def to_h
      @data.dup
    end

    private

    def assign_sections
      @base_branch = @data.fetch('base_branch')
      @commands = @data.fetch('commands')
      @review = @data.fetch('review')
      @merge = @data.fetch('merge')
    end
  end
end
