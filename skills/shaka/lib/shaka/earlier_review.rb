# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_review_evidence'

module Shaka
  # Says which published local review still covers a head when a description received no results.
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

    def describe(found, base)
      review = found['comment'].to_s.match?(URL) ? "[local review](#{found['comment']})" : 'local review'
      applies = "The #{review} of `#{found['reviewed'].to_s[0, 7]}` still applies:"
      case found['basis']
      when 'current_head' then "A #{review} of this revision is published, but its result was not supplied."
      when 'unchanged_since_review'
        "#{applies} this revision only adds a clean merge of #{base.match?(BRANCH) ? "`#{base}`" : 'the base branch'}."
      when 'markdown_only_since_review' then "#{applies} only Markdown changed since."
      end
    end
  end
end
