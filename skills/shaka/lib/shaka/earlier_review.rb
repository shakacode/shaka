# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_review_evidence'

module Shaka
  # Says which published local review covers a head when a description received no results.
  # It asks the same question merge asks, so the sentence claims no more than merge accepts: a
  # review of this head, or of an earlier commit when only Markdown changed since or the head is a
  # clean merge of it with the base. It binds nothing and never speaks for validation. It names no
  # reviewer, because an attestation's closing line names only one reviewer of a batch.
  module EarlierReview
    URL = %r{\Ahttps://\S+\z}
    # A backtick or space would break the code span the branch name is shown in.
    BRANCH = /\A[^`\s]+\z/

    module_function

    # The sentence, or nil when no published review covers the head or GitHub cannot say.
    def sentence(github, pull, root: nil)
      head = pull.dig('head', 'sha')
      base = pull.dig('base', 'ref')
      return unless head && base

      describe(MergeReviewEvidence.new(github, root:).call(head, base:), base)
    rescue Error, SystemCallError
      nil
    end

    # Says the review covers the revision, not that it found nothing: its findings are in the comment.
    def describe(found, base)
      review = found['comment'].to_s.match?(URL) ? "[local review](#{found['comment']})" : 'local review'
      covers = "The #{review} of `#{found['reviewed'].to_s[0, 7]}` also covers this revision, which"
      case found['basis']
      when 'current_head' then "A #{review} of this revision is published, but its result was not passed in."
      when 'unchanged_since_review'
        "#{covers} only updates it from #{base.match?(BRANCH) ? "`#{base}`" : 'the base branch'} with no other changes."
      when 'markdown_only_since_review' then "#{covers} changes only Markdown since."
      end
    end
  end
end
