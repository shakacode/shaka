# frozen_string_literal: true

require_relative '../error'
require_relative '../workflow_version'
require_relative 'task_source_line'

module Shaka
  # Renders a small, allowlisted record of route-selection evidence for a public PR.
  # The helper supplies the workflow version itself, so the row names the code that ran.
  # An optional task_number links the task when it is an issue or PR in the same repository.
  class ExecutionProvenance
    FIELDS = %w[task_source initial_prompt requested_model requested_effort
                recommended_model recommended_effort active_model active_effort].freeze
    OPTIONAL_FIELDS = %w[task_number task_relation task_tracker task_key task_url].freeze
    TASK_SOURCES = %w[description issue pull_request].freeze
    TASK_PATHS = { 'issue' => 'issues', 'pull_request' => 'pull' }.freeze
    REQUESTED_FIELDS = %w[requested_model requested_effort].freeze
    NOT_SPECIFIED = 'Not specified'
    SAFE_VALUE = /\A(?:UNKNOWN|[A-Za-z0-9][A-Za-z0-9._:-]{0,79})\z/

    def initialize(spec, workflow_version: nil, pull: nil)
      @spec = spec
      @workflow_version = workflow_version || WorkflowVersion.current
      @repository = pull&.dig('base', 'repo', 'full_name')
    end

    def detail
      { 'summary' => 'Execution details', 'body' => table }
    end

    # The Task line in Intent, so the summary need not restate the task to link it.
    def line(agent)
      validated
      TaskSourceLine.render(@spec, agent)
    end

    # The values a provenance history entry compares, as the table renders them.
    def entry
      values = validated
      { 'workflow' => @workflow_version.markdown, 'requested' => route(values, 'requested'),
        'recommended' => route(values, 'recommended'), 'active' => route(values, 'active') }
    end

    private

    def table
      ([%w[Field Value], %w[--- ---]] + rows).map { |row| "| #{row.join(' | ')} |" }.join("\n")
    end

    def rows
      values = validated
      [
        ['Task source', task(values.fetch('task_source'))],
        ['Shaka skill version', @workflow_version.markdown],
        (['User-requested model / effort', route(values, 'requested')] unless
          REQUESTED_FIELDS.all? { |field| values.fetch(field).nil? }),
        ['Recommended model / effort', route(values, 'recommended')],
        ['Active model / effort', route(values, 'active')]
      ].compact
    end

    def validated
      validate_schema

      FIELDS.to_h do |field|
        value = @spec.fetch(field)
        unless valid?(value) || (REQUESTED_FIELDS.include?(field) && value.nil?)
          raise Error, "Publication provenance #{field} is invalid."
        end

        [field, value]
      end
    end

    def validate_schema
      raise Error, 'Publication provenance must be an object.' unless @spec.is_a?(Hash)

      validate_fields
      validate_task_source
      validate_task_number
      TaskSourceLine.validate!(@spec)
      validate_prompt_exclusion
    end

    def validate_fields
      return if (@spec.keys - OPTIONAL_FIELDS).sort == FIELDS.sort

      raise Error, 'Publication provenance fields do not match the metadata allowlist.'
    end

    def validate_task_source
      return if TASK_SOURCES.include?(@spec['task_source'])

      raise Error, 'Publication provenance task_source is invalid.'
    end

    def validate_task_number
      return unless @spec.key?('task_number')
      return if TASK_PATHS.key?(@spec['task_source']) && @spec['task_number'].is_a?(Integer) &&
                @spec['task_number'].positive?

      raise Error, 'Publication provenance task_number must be a positive issue or pull request number.'
    end

    def validate_prompt_exclusion
      return if @spec['initial_prompt'] == 'EXCLUDED'

      raise Error, 'Publication provenance initial_prompt must be EXCLUDED.'
    end

    def task(source)
      number = @spec['task_number']
      return source unless number
      return "#{source} ##{number}" unless @repository

      "#{source} [##{number}](https://github.com/#{@repository}/#{TASK_PATHS.fetch(source)}/#{number})"
    end

    def valid?(value) = value.is_a?(String) && value.match?(SAFE_VALUE)

    def route(values, name)
      parts = %w[model effort].map { |setting| values.fetch("#{name}_#{setting}") }
      return NOT_SPECIFIED if parts.all?(&:nil?)

      parts.map { |value| value || NOT_SPECIFIED }.join(' / ')
    end
  end
end
