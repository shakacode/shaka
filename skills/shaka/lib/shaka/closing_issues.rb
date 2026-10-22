# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Compares the issues a description says it fixes with the ones GitHub will close on merge.
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
    # Each reference in a list after one keyword counts as claimed, so the note can name the unlinked ones.
    CLAIM = /\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?\s+(#{REFERENCE}(?:\s*(?:,|,?\s*and|&)\s*#{REFERENCE})*)/i
    FIELDS = %w[why scope root_cause].freeze
    # A read that fails or comes back partial is reported, never raised, because the note is advisory.
    FAILURES = [Error, KeyError, TypeError, SystemCallError].freeze

    module_function

    # The summary and intent, the text a description's reader takes as the PR's claim.
    def texts(content)
      intent = content['intent'].is_a?(Hash) ? content['intent'] : {}
      [content['summary'], *intent.values_at(*FIELDS)].grep(String)
    end

    # Each issue the texts say this PR fixes, as OWNER/REPO#N.
    def claimed(texts, repository)
      texts.flat_map { |text| text.scan(CLAIM).flatten }.flat_map { |list| list.scan(REFERENCE) }
           .map { |reference| normalize(reference, repository) }.uniq
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

    # Names each claimed issue GitHub will not close; reads GitHub only when the texts claim one.
    def note(content, github)
      claimed = claimed(texts(content), github.repository)
      return {} if claimed.empty?

      missing = claimed - linked(github).map(&:downcase)
      missing.empty? ? {} : { 'closing_issues' => missing_note(missing, github.repository) }
    rescue *FAILURES => e
      { 'closing_issues' => "Closing issue references could not be read: #{e.message}" }
    end

    # The issues a merge would close, for a handoff to name before anyone merges.
    def fact(github)
      issues = linked(github).map { |issue| short(issue, github.repository) }
      issues.empty? ? 'closes no issues' : "closes #{issues.join(', ')}"
    rescue *FAILURES => e
      "closing issues unavailable: #{e.message}"
    end

    def normalize(reference, repository)
      reference = reference.sub(%r{\Ahttps://github\.com/([^/]+/[^/]+)/issues/}i, '\1#')
      (reference.start_with?('#') ? "#{repository}#{reference}" : reference).downcase
    end

    def short(issue, repository) = issue.downcase.start_with?("#{repository.downcase}#") ? issue[/#\d+\z/] : issue

    def missing_note(missing, repository)
      names = missing.map { |issue| short(issue, repository) }.join(', ')
      "The description says this PR fixes #{names}, but GitHub will not close #{missing.one? ? 'it' : 'them'} " \
        'on merge. Put a keyword before each issue, as in `Fixes #1, fixes #2`, or say `Part of` ' \
        'when the issue stays open.'
    end
  end
end
