# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Renders the Task line in a description's Intent: where the work came from and how the PR relates to it,
  # so the summary need not restate the task just to link it.
  module TaskSourceLine
    RELATIONS = { 'fixes' => 'fixes', 'part_of' => 'part of', 'follow_up' => 'follow-up', 'refs' => 'related' }.freeze
    TRACKERS = { 'jira' => 'Jira', 'linear' => 'Linear' }.freeze
    KEY = /\A[A-Z][A-Z0-9_]*-\d+\z/
    # A link target cannot close the Markdown link around it or open another.
    URL = %r{\Ahttps://[^\s()<>\[\]]+\z}

    # A relation names a numbered or keyed task, and only a GitHub issue can be closed by merging.
    def self.validate!(spec)
      validate_tracker!(spec)
      return if !spec.key?('task_relation') || relation?(spec)

      raise Error, 'Publication provenance task_relation must be fixes, part_of, follow_up, or refs, ' \
                   'with a task_number or task_key; fixes needs a GitHub issue number.'
    end

    # Another tracker's ticket is named by its key, and linked only when the agent supplies a shareable URL.
    def self.validate_tracker!(spec)
      return if %w[task_tracker task_key task_url].none? { |field| spec.key?(field) } || ticket?(spec)

      raise Error, 'Publication provenance task_tracker must be jira or linear, with an issue task_source, ' \
                   'a task_key such as MKT-1234, no task_number, and an optional https task_url.'
    end

    def self.relation?(spec)
      relation = spec['task_relation']
      return false unless RELATIONS.key?(relation) && (spec.key?('task_number') || spec.key?('task_key'))

      relation != 'fixes' || (spec['task_source'] == 'issue' && spec.key?('task_number'))
    end

    def self.ticket?(spec)
      TRACKERS.key?(spec['task_tracker']) && matches?(spec['task_key'], KEY) && spec['task_source'] == 'issue' &&
        !spec.key?('task_number') && (!spec.key?('task_url') || matches?(spec['task_url'], URL))
    end

    def self.matches?(value, pattern) = value.is_a?(String) && value.match?(pattern)

    # GitHub closes an issue only when its keyword directly precedes the bare reference, so a fix renders
    # its keyword before the number; the closing-issue note checks this claim like summary text.
    def self.closing_claim(spec)
      return unless spec.is_a?(Hash) && spec['task_relation'] == 'fixes' && spec['task_number'].is_a?(Integer)

      "#{RELATIONS.fetch('fixes')} ##{spec['task_number']}"
    end

    # A prompt is named after the agent that took it, such as Claude Code's "Claude prompt".
    def self.render(spec, agent)
      return "**Task:** #{prompt(agent)}" if spec.fetch('task_source') == 'description'
      return "**Task:** GitHub · #{closing_claim(spec)}" if closing_claim(spec)

      "**Task:** #{task(spec)}#{suffix(spec)}"
    end

    # The identity's display name, so `claude` and `Claude Code` both read "Claude prompt".
    def self.prompt(agent)
      name = PublicationText.identity_field(agent, 'agent').delete_suffix(' Code')
      name == 'UNKNOWN' ? 'task description' : "#{name} prompt"
    end

    def self.task(spec)
      return "GitHub#{' PR' if spec['task_source'] == 'pull_request'} ##{spec['task_number']}" if spec['task_number']
      return 'issue' unless spec['task_tracker']

      name = "#{TRACKERS.fetch(spec['task_tracker'])} #{spec['task_key']}"
      spec['task_url'] ? "[#{name}](#{spec['task_url']})" : name
    end

    def self.suffix(spec)
      relation = spec['task_relation']
      relation ? " · #{RELATIONS.fetch(relation)}" : ''
    end

    private_class_method :validate_tracker!, :relation?, :ticket?, :matches?, :prompt, :task, :suffix
  end
end
