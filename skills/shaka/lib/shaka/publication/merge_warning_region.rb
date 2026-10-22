# frozen_string_literal: true

require_relative '../error'
require_relative '../post_implementation_report'

module Shaka
  # Keeps the checkpoint warning ahead of a newly inserted feature description.
  module MergeWarningRegion
    OPEN = '<!-- shaka:merge-warning:begin -->'
    CLOSE = '<!-- shaka:merge-warning:end -->'
    BLOCKED = ['⛔ Do not merge — post-implementation checkpoint blocked.',
               'Task owner: resolve the linked concerns and publish a new checkpoint for the current head.'].freeze
    # An owner who would merge after the maintainer's decision is not told the PR must never merge.
    AWAITING = ["⛔ Not ready to merge — waiting for the maintainer's decision.",
                'Maintainer: make the decision the linked checkpoint asks for. ' \
                'Task owner: then publish a new checkpoint.'].freeze

    module_function

    # The heading and next step for a blocked checkpoint with this owner disposition.
    def wording(disposition) = disposition == PostImplementationReport::AWAITING_DECISION ? AWAITING : BLOCKED

    def prepend(existing, managed)
      warning, remaining = split(existing)
      "#{warning}#{managed}\n\n#{remaining}"
    end

    def remove(body) = split(body).last

    # The head on the warning's generated last line; quoted summary text precedes it.
    def head(body, repository)
      link = %r{· Head \[`\h{7}`\]\(https://github\.com/#{Regexp.escape(repository)}/commit/(\h{40})\)\. Passing}
      split(body).first.scan(link).last&.first
    end

    # Whether the warning for this head waits on the maintainer; only its generated first line counts.
    def awaiting?(body, repository, current)
      split(body).first.start_with?("#{OPEN}\n> **#{AWAITING.first}**\n") && head(body, repository) == current
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
