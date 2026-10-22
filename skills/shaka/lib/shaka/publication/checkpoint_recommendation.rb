# frozen_string_literal: true

require_relative '../error'
require_relative '../post_implementation/evidence'
require_relative 'merge_warning_region'

module Shaka
  # Reads the description's recommendation and verification verdict from the checkpoint published for its head,
  # so the headline cannot disagree with that checkpoint.
  module CheckpointRecommendation
    module_function

    def resolve(content, github)
      checkpoint = content['checkpoint']
      return content unless checkpoint.is_a?(Hash)

      supplied = checkpoint.keys & %w[recommendation verification_adequacy]
      raise Error, "Description checkpoint #{supplied.first} comes from the published checkpoint; omit it." if
        supplied.any?

      published = published(PostImplementationEvidence.new(github), checkpoint['head'])
      published.empty? ? content : content.merge('checkpoint' => checkpoint.merge(published))
    end

    def published(evidence, head)
      { 'recommendation' => evidence.recommendation(head), 'verification_adequacy' => evidence.adequacy(head) }.compact
    end

    # A waiting banner sends the maintainer to the description, so that description must list the question,
    # whether or not it carries a checkpoint object.
    def require_decisions!(content, pull, repository)
      decisions = content['decisions']
      return if decisions.is_a?(Array) && decisions.any?
      return unless MergeWarningRegion.awaiting?(pull['body'].to_s, repository, pull.dig('head', 'sha'))

      raise Error, 'The checkpoint waits for a maintainer decision; list that question in decisions.'
    end
  end
end
