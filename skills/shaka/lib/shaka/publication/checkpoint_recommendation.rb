# frozen_string_literal: true

require_relative '../decision_labels'
require_relative '../error'
require_relative '../post_implementation/evidence'
require_relative 'merge_warning_region'
require_relative 'publishing'

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
      return if open_decisions?(content)
      return unless MergeWarningRegion.awaiting?(pull['body'].to_s, repository, pull.dig('head', 'sha'))

      raise Error, 'The checkpoint waits for a maintainer decision; list that question in decisions.'
    end

    # An open question contradicts a checkpoint that still recommends merging this head.
    def refuse_decisions_under_merge!(content, pull, github)
      return unless open_decisions?(content)
      return unless PostImplementationEvidence.new(github).recommendation(pull.dig('head', 'sha')) == 'Merge'

      raise Error, "This head's checkpoint recommends Merge. Before asking, publish the same result again with " \
                   "#{PostImplementationReport::AWAITING_DECISION}, and with Merge once answered. " \
                   'When only merge approval remains, run `attention --state merge` instead of listing a decision.'
    end

    # The same contradiction from the other side. A waiting warning for this head is the way back: Merge settles it,
    # and the decisions clear next.
    def refuse_merge_over_decisions!(github, head)
      body = github.api("repos/#{github.repository}/pulls/#{github.number}")['body'].to_s
      return unless DecisionLabels.asks_for_decisions?(Publishing.managed_region(body.gsub("\r\n", "\n")).to_s)
      return if MergeWarningRegion.awaiting?(body, github.repository, head)

      raise Error, 'The description still lists decisions. Publish an empty list once they are answered, or ' \
                   "recommend #{PostImplementationReport::AWAITING_DECISION}."
    end

    def open_decisions?(content)
      decisions = content['decisions']
      decisions.is_a?(Array) && decisions.any?
    end
  end
end
