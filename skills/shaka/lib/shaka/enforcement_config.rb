# frozen_string_literal: true

require 'yaml'
require_relative 'enforcement_coverage'
require_relative 'error'
require_relative 'repository_config/duplicate_keys'
require_relative 'workflow_config'

module Shaka
  # Loads the audit that records what enforces each imperative rule in workflow.yml.
  class EnforcementConfig
    PATH = File.expand_path('../../config/enforcement.yml', __dir__)
    ROOT_KEYS = %w[version rules].freeze
    RULE_KEYS = %w[id phase quote enforced_by detector note].freeze
    BACKED = %w[code reported github].freeze
    ENFORCERS = [*BACKED, 'agent'].freeze

    def self.load(source: nil, workflow: nil)
      source ||= File.read(PATH, encoding: 'UTF-8')
      new(source:, workflow: workflow || WorkflowConfig.load).load
    end

    def initialize(source:, workflow:)
      @source = source
      @workflow = workflow
    end

    def load
      RepositoryConfig::DuplicateKeys.check(@source, filename: 'enforcement.yml')
      data = YAML.safe_load(@source, permitted_classes: [], permitted_symbols: [], aliases: false)
      validate(data)
      data
    rescue Psych::Exception => e
      raise Error, "Invalid enforcement.yml: #{e.message}"
    end

    private

    def validate(data)
      mapping!(data, 'enforcement')
      exact_keys!(data, ROOT_KEYS, 'enforcement')
      raise Error, 'enforcement version must be 1' unless data['version'] == 1

      rules = data['rules']
      raise Error, 'enforcement rules must be a non-empty list' unless rules.is_a?(Array) && !rules.empty?

      rules.each { |rule| rule!(rule) }
      unique_ids!(rules)
      EnforcementCoverage.new(@workflow).check(rules)
    end

    def rule!(rule)
      mapping!(rule, 'rule')
      text!(rule['id'], 'rule id')
      label = "rule #{rule['id']}"
      unknown = rule.keys - RULE_KEYS
      raise Error, "unknown #{label} key: #{unknown.first}" unless unknown.empty?

      quote!(rule, label)
      enforcement!(rule, label)
    end

    def quote!(rule, label)
      text!(rule['quote'], "#{label} quote")
      return if EnforcementCoverage::MARKER.match?(rule['quote'])

      raise Error, "#{label} quote states no rule"
    end

    # A rule something other than the agent touches names that mechanism; an agent-enforced
    # rule instead says so in as many words, the outcome this audit exists to make visible.
    def enforcement!(rule, label)
      by = rule['enforced_by']
      raise Error, "#{label} enforced_by must be #{ENFORCERS.join(', ')}" unless ENFORCERS.include?(by)

      expected, unexpected = BACKED.include?(by) ? %w[detector note] : %w[note detector]
      text!(rule[expected], "#{label} #{expected}")
      raise Error, "#{label} is #{by}-enforced, so it takes no #{unexpected}" if rule.key?(unexpected)
    end

    def unique_ids!(rules)
      repeated = rules.map { |rule| rule['id'] }.tally.find { |_, count| count > 1 }
      raise Error, "duplicate rule id: #{repeated.first}" if repeated
    end

    def mapping!(value, label)
      valid = value.is_a?(Hash) && value.keys.all?(String)
      raise Error, "#{label} must be a mapping with string keys" unless valid
    end

    def exact_keys!(mapping, expected, label)
      unknown = mapping.keys - expected
      missing = expected - mapping.keys
      raise Error, "unknown #{label} key: #{unknown.first}" unless unknown.empty?
      raise Error, "missing #{label} key: #{missing.first}" unless missing.empty?
    end

    def text!(value, label)
      raise Error, "#{label} must be non-empty text" unless value.is_a?(String) && !value.strip.empty?
    end
  end
end
