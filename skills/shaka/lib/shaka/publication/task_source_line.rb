# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Renders the visible line under a description's summary that says how the PR relates to its task,
  # so the summary need not restate the task just to link it.
  module TaskSourceLine
    # GitHub closes an issue only when its keyword directly precedes the bare reference.
    RELATIONS = { 'fixes' => 'Fixes', 'part_of' => 'Part of', 'follow_up' => 'Follow-up to', 'refs' => 'Refs' }.freeze
    NAMES = { 'description' => 'task description', 'issue' => 'issue', 'pull_request' => 'pull request' }.freeze

    # A relation names a numbered task, and only an issue can be closed by merging.
    def self.validate!(spec)
      return unless spec.key?('task_relation')

      relation = spec['task_relation']
      return if RELATIONS.key?(relation) && spec.key?('task_number') &&
                (relation != 'fixes' || spec['task_source'] == 'issue')

      raise Error, 'Publication provenance task_relation must be fixes, part_of, follow_up, or refs, ' \
                   'with a task_number; fixes needs an issue.'
    end

    # The closing keyword the line renders, so the closing-issue note checks it like summary text.
    def self.closing_claim(spec)
      return unless spec.is_a?(Hash) && spec['task_relation'] == 'fixes' && spec['task_number'].is_a?(Integer)

      "#{RELATIONS.fetch('fixes')} ##{spec['task_number']}"
    end

    def self.render(spec)
      name = NAMES.fetch(spec.fetch('task_source'))
      number = spec['task_number']
      return "**Task source:** #{name}" unless number

      "**Task source:** #{RELATIONS.fetch(spec['task_relation'], name)} ##{number}"
    end
  end
end
