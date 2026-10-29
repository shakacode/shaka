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
    # A link target starts its host with a letter or digit, and cannot close or escape the Markdown link
    # around it, or open another.
    URL = %r{\Ahttps://[A-Za-z0-9][^\s()<>\[\]\\/?#]*(?:[/?#][^\s()<>\[\]\\]*)?\z}

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

    # What the line tells the closing-issue note: a fix claims its issue, and any other relation
    # leaves the issue open, which the note reads as `Part of`.
    def self.claims(spec)
      return [] unless spec.is_a?(Hash) && RELATIONS.key?(spec['task_relation']) && spec['task_number'].is_a?(Integer)

      [closing_claim(spec) || "Part of ##{spec['task_number']}"]
    end

    # A published Task line that leaves its issue open, read back as `Part of` for the merge handoff.
    PUBLISHED_PARTIAL = /^\*\*Task:\*\* GitHub #(\d+) · (?:part of|follow-up|related)\r?$/

    # The provenance row `description` renders for an issue task, read back from the published body.
    def self.published_task(body, repository)
      link = %r{\[#(\d+)\]\(https://github\.com/#{Regexp.escape(repository)}/issues/\1\)}i
      number = body[/^\| Task source \| issue #{link} \|/, 1]
      "#{repository}##{number}".downcase if number
    end

    def self.published_claims(body) = body.scan(PUBLISHED_PARTIAL).map { |(number)| "Part of ##{number}" }

    # The task's issue when only a fixes task_relation claims it; a prose claim is corrected in prose.
    def self.fixes_issue(content, task)
      provenance = content['provenance']
      task if provenance.is_a?(Hash) && provenance['task_relation'] == 'fixes'
    end

    # When the Task line leaves the task's issue open but the prose says this PR fixes it, the description
    # contradicts itself whether or not GitHub links the issue. The task's issue is always in this repository.
    def self.contradiction(content, task, claimed)
      spec = content['provenance']
      relation = spec['task_relation'] if spec.is_a?(Hash)
      return unless task && RELATIONS.key?(relation) && relation != 'fixes' && claimed.include?(task)

      issue = task[/#\d+\z/]
      "The Task line says #{issue} stays open, but the summary or intent says this PR fixes it. Set provenance " \
        '`task_relation` to `fixes` when this PR resolves it, or remove the closing keyword when it stays open.'
    end

    # How to say an unlinked issue stays open: task_relation covers only the task's own issue.
    # When the prose also claims the task's issue, both places must change, so the advice names both.
    def self.stays_open_advice(missing, relation, prose)
      return '`Part of`' unless relation && missing.include?(relation)

      task = '`task_relation` `part_of`'
      task += ' and `Part of` in the prose' if prose.include?(relation)
      (missing - [relation]).empty? ? task : "#{task} for the task's issue and `Part of` for the others"
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
      return spec['task_source'] == 'pull_request' ? 'pull request' : 'issue' unless spec['task_tracker']

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
