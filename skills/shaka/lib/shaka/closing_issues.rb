# frozen_string_literal: true

require_relative 'error'
require_relative 'publication/task_source_line'

module Shaka
  # Compares the issues a description and its task name with the ones GitHub will close on merge.
  # GitHub links an issue only when its reference directly follows a closing keyword, so
  # "Fixes #1 and #2" closes #1 alone; the notes it returns are advisory.
  module ClosingIssues
    QUERY = <<~GRAPHQL
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $number) {
            closingIssuesReferences(first: 100) { totalCount nodes { number repository { nameWithOwner } } }
          }
        }
      }
    GRAPHQL
    REFERENCE = %r{(?<![\w/])(?:[\w.-]+/[\w.-]+)?\#\d+(?!\w)|https://github\.com/[\w.-]+/[\w.-]+/issues/\d+(?![\w/])}i
    LIST = /#{REFERENCE}(?:\s*(?:,|,?\s*and|&)\s*#{REFERENCE})*/
    # Each reference in a list after one keyword counts as claimed, so the note can name the unlinked ones.
    CLAIM = /\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?\s+(#{LIST})/i
    # Partial work names its issue with no keyword, so the task's issue is expected to stay open.
    PARTIAL = /\bpart\s+of:?\s+(#{LIST})/i
    FIELDS = %w[why scope root_cause].freeze
    # GitHub links no keyword inside code, so a quoted example such as `Fixes #1` claims nothing.
    CODE = /(`+).*?\1/m
    # A read that fails or comes back partial is reported, never raised, because the note is advisory.
    FAILURES = [Error, KeyError, TypeError, SystemCallError].freeze

    module_function

    # The summary, intent, and Task line: the text a description's reader takes as the PR's claim.
    def texts(content)
      intent = content['intent'].is_a?(Hash) ? content['intent'] : {}
      [content['summary'], *intent.values_at(*FIELDS), *TaskSourceLine.claims(content['provenance'])].grep(String)
    end

    # Each issue the texts say this PR fixes, as OWNER/REPO#N.
    def claimed(texts, repository, pattern = CLAIM)
      texts.flat_map { |text| text.gsub(CODE, ' ').scan(pattern).flatten }.flat_map { |list| list.scan(REFERENCE) }
           .map { |reference| normalize(reference, repository) }.uniq
    end

    # The issue the task came from, as OWNER/REPO#N, when provenance records one.
    def task_issue(content, repository)
      provenance = content['provenance']
      number = provenance['task_number'] if provenance.is_a?(Hash) && provenance['task_source'] == 'issue'
      "#{repository}##{number}".downcase if number.is_a?(Integer)
    end

    # Each issue GitHub will close when this PR merges, as OWNER/REPO#N.
    def linked(github)
      owner, name = github.repository.split('/')
      data = github.graphql(QUERY, owner:, name:, number: github.number)
      nodes(data.dig('repository', 'pullRequest', 'closingIssuesReferences'))
        .map { |node| "#{node.dig('repository', 'nameWithOwner')}##{node.fetch('number')}" }
    end

    # A page shorter than the total would hide linked issues, so it is refused rather than trusted.
    def nodes(references)
      nodes = references['nodes'] if references.is_a?(Hash)
      raise Error, 'GitHub returned no closing issue references.' unless nodes.is_a?(Array)
      raise Error, 'GitHub lists more closing issues than one page holds.' if references['totalCount'] != nodes.size

      nodes.compact
    end

    # Names each claimed issue GitHub will not close, the task's issue left open without `Part of`,
    # and each issue GitHub will close that neither the task nor the texts name.
    def note(content, github)
      notes = notes(content, github)
      notes.empty? ? {} : { 'closing_issues' => notes.join(' ') }
    rescue *FAILURES => e
      { 'closing_issues' => "Closing issue references could not be read: #{e.message}" }
    end

    def notes(content, github)
      repository = github.repository
      texts = texts(content)
      claimed = claimed(texts, repository)
      task = task_issue(content, repository)
      linked = linked(github).map(&:downcase)
      [missing_note(claimed - linked, repository),
       task_note(left_open(task, linked + claimed, texts, repository), repository),
       extra_note(linked - expected(claimed, task, texts, repository), repository)].compact
    end

    # The issues a merge would close, for a handoff to name before anyone merges, and the
    # published task issue it would leave open when the body does not say `Part of` it.
    def fact(github, body = nil)
      repository = github.repository
      linked = linked(github)
      closes = linked.empty? ? 'closes no issues' : "closes #{names(linked, repository)}"
      texts = [body.to_s, *TaskSourceLine.published_claims(body.to_s)]
      task = left_open(published_task(body.to_s, repository), linked.map(&:downcase), texts, repository)
      task ? "#{closes}; task issue #{short(task, repository)} stays open" : closes
    rescue *FAILURES => e
      "closing issues unavailable: #{e.message}"
    end

    # The task's issue is expected to close too, unless the texts say this PR is only part of it.
    def expected(claimed, task, texts, repository) = claimed | ([task].compact - claimed(texts, repository, PARTIAL))

    # The task's issue when the merge leaves it open and no text says this PR is only part of it.
    def left_open(task, expected, texts, repository)
      task unless task.nil? || [*expected, *claimed(texts, repository, PARTIAL)].include?(task)
    end

    # The provenance row `description` renders for an issue task, read back from the published body.
    def published_task(body, repository)
      link = %r{\[#(\d+)\]\(https://github\.com/#{Regexp.escape(repository)}/issues/\1\)}i
      number = body[/^\| Task source \| issue #{link} \|/, 1]
      "#{repository}##{number}".downcase if number
    end

    def normalize(reference, repository)
      reference = reference.sub(%r{\Ahttps://github\.com/([^/]+/[^/]+)/issues/}i, '\1#')
      (reference.start_with?('#') ? "#{repository}#{reference}" : reference).downcase
    end

    def short(issue, repository) = issue.downcase.start_with?("#{repository.downcase}#") ? issue[/#\d+\z/] : issue

    def names(issues, repository) = issues.map { |issue| short(issue, repository) }.join(', ')

    def missing_note(missing, repository)
      return if missing.empty?

      "The description says this PR fixes #{names(missing, repository)}, but GitHub will not close " \
        "#{missing.one? ? 'it' : 'them'} on merge. Merge into the default branch with a keyword before each issue, " \
        'as in `Fixes #1, fixes #2`, or use `task_relation` `part_of` or `Part of` when the issue stays open.'
    end

    def task_note(task, repository)
      task && "This PR comes from the task's issue #{short(task, repository)}, but GitHub will not close it " \
              'on merge. Set provenance `task_relation` to `fixes` when this PR resolves it, or ' \
              '`part_of` when it stays open.'
    end

    def extra_note(extra, repository)
      return if extra.empty?

      them = extra.one? ? 'it' : 'them'
      "GitHub will also close #{names(extra, repository)} on merge, though neither the task nor the summary and " \
        "intent say this PR fixes #{them}. Remove the closing keyword or manual link unless the task may close #{them}."
    end
  end
end
