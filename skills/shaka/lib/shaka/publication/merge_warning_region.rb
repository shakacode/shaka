# frozen_string_literal: true

require_relative '../error'
require_relative '../post_implementation_report'

module Shaka
  # Keeps the checkpoint warning ahead of a newly inserted feature description.
  module MergeWarningRegion
    OPEN = '<!-- shaka:merge-warning:begin -->'
    CLOSE = '<!-- shaka:merge-warning:end -->'
    # Detection reads this hidden line, so the visible heading can change without losing open warnings.
    AWAITING_MARKER = '<!-- shaka:merge-warning:awaiting -->'
    # Warnings published before the marker existed are still recognized by their first line.
    LEGACY_AWAITING = "⛔ Not ready to merge — waiting for the maintainer's decision."
    AWAITING = ['⛔ Not ready to merge: a maintainer needs to answer a question.',
                'Answer the question below under Decisions to make. ' \
                'Your answer does not approve merging. The agent records it and updates this PR.'].freeze
    BLOCKED = ['⛔ Do not merge yet: the final review raised concerns.',
               'The agent addresses the concerns in the linked report and runs the review again.'].freeze
    REJECTED = ['⛔ Do not merge: this PR should be closed or replaced.',
                'A maintainer decides whether to close or replace it.'].freeze
    INCOMPLETE = ['⛔ Do not merge yet: the final review did not finish.',
                  'The agent fixes what stopped the review and runs it again.'].freeze

    module_function

    # The heading and default next step for a blocked checkpoint publication. Either the reviewer or the owner
    # recommending against the PR leaves closing or replacing it to a maintainer.
    def wording(publication)
      return AWAITING if waiting?(publication)
      return INCOMPLETE if publication.state == 'not_completed'

      [publication.disposition, publication.conclusion].include?('Do not merge') ? REJECTED : BLOCKED
    end

    # The warning for a blocked checkpoint publication, quoting its reason; report and commit are rendered links.
    def render(publication, report:, commit:)
      heading, step = wording(publication)
      marker = "#{AWAITING_MARKER}\n" if waiting?(publication)
      "#{OPEN}\n#{marker}> **#{heading}**\n>\n#{quote(publication.summary)}\n>\n> #{next_step(publication, step)}\n" \
        ">\n> [Final review report](#{report}) · Head #{commit}. " \
        "This PR stays a draft until a new review clears this warning and required checks pass.\n#{CLOSE}\n\n"
    end

    # The owner's own next step is more specific than the fixed one. A waiting warning keeps only its request for
    # an answer, because the owner's step there is the agent's own bookkeeping. A close-or-replace warning keeps
    # the maintainer's decision ahead of the owner's step.
    def next_step(publication, fixed)
      return fixed if publication.next_action.nil? || waiting?(publication)

      owner = "**Next:** #{escape(publication.next_action.split.join(' '))}"
      fixed == REJECTED.last ? "#{fixed} #{owner}" : owner
    end

    def waiting?(publication) = publication.disposition == PostImplementationReport::AWAITING_DECISION

    def quote(text) = text.lines.map { |line| "> #{escape(line.chomp)}" }.join("\n")

    def escape(text) = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

    def prepend(existing, managed)
      warning, remaining = split(existing)
      "#{warning}#{managed}\n\n#{remaining}"
    end

    def remove(body) = split(body).last

    # The head on the warning's generated last line; quoted summary text precedes it.
    def head(body, repository)
      link = %r{· Head \[`\h{7}`\]\(https://github\.com/#{Regexp.escape(repository)}/commit/(\h{40})\)\.}
      split(body).first.scan(link).last&.first
    end

    # Whether the warning for this head waits on the maintainer; only its generated first line counts.
    def awaiting?(body, repository, current)
      warning = split(body).first
      starts = ["#{OPEN}\n#{AWAITING_MARKER}\n", "#{OPEN}\n> **#{LEGACY_AWAITING}**\n"]
      starts.any? { |start| warning.start_with?(start) } && head(body, repository) == current
    end

    # A merge of the head the warning waited on answers it; any other warning stays as the record.
    def answered_by_merge(body, repository, pull)
      return body unless pull['merged'] == true && awaiting?(body, repository, pull.dig('head', 'sha'))

      remove(body)
    end

    # Whether a ready checkpoint for this head settles the warning: it names an earlier head, or it waited
    # only on the maintainer's decision for this one.
    def settled_by_ready?(body, repository, current)
      ![nil, current].include?(head(body, repository)) || awaiting?(body, repository, current)
    end

    def split(body)
      return ['', body] if body.scan(OPEN).empty? && body.scan(CLOSE).empty?

      validate(body)
      prefix, rest = body.split(OPEN, 2)
      warning, suffix = rest.split(CLOSE, 2)
      ["#{OPEN}#{warning}#{CLOSE}\n\n", "#{prefix}#{suffix.delete_prefix("\n\n")}"]
    end

    def validate(body)
      return if body.scan(OPEN).one? && body.scan(CLOSE).one? && body.index(OPEN) < body.index(CLOSE)

      raise Error, 'Merge warning markers are ambiguous or malformed; repair them before retrying.'
    end
  end
end
