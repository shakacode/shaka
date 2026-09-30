# frozen_string_literal: true

require_relative '../error'
require_relative '../publication/text'

module Shaka
  # Which ledger rounds form the last batch: the reviewers that read the last reviewed commit.
  module LocalReviewLedgerBatch
    private

    def check_batch_recorded!
      unrecorded = batch.find { |index| !recorded?(rounds[index]) }
      raise Error, "Record round #{unrecorded + 1}'s findings with `shaka review record` before the next round." if
        unrecorded
    end

    # Indexes of the rounds that reviewed the last head.
    def batch = rounds.each_index.select { |index| rounds[index]['head'] == last_head }

    # Another reviewer may join the last batch until it is triaged; any other repeat of a commit
    # needs a fix first.
    def check_new_head!(head, reviewer)
      reviewed = rounds.index { |round| round['head'] == head && !joins?(round, head, reviewer) }
      raise Error, "Round #{reviewed + 1} already reviewed #{head}; commit the fix first." if reviewed
      return unless head == last_head && batch.any? { |index| rounds[index].key?('findings') }

      raise Error, "#{head}'s findings are already recorded; start every reviewer of a commit before recording."
    end

    # Every round of the last batch gets the findings its reviewer reported, from one triage.
    def recorded_rounds(content)
      findings = PublicationText.list(content['findings'], 'recorded finding')
      rounds.each_with_index.map do |round, index|
        batch.include?(index) ? triaged(round, index, findings, content) : round
      end
    end

    def triaged(round, index, findings, content)
      mine = findings.select { |finding| reported?(finding, round) }.map { |finding| finding.except('reviewers') }
      round = round.merge({ 'findings' => mine }, usage_for(content, round['reviewer']))
      check_findings!(round, index + 1)
      round
    end

    # With one round, a finding need not name its reviewer; any name it gives must be in the batch.
    def reported?(finding, round)
      named = finding['reviewers']
      return true if named.nil? && batch.one?

      check_reviewers!(finding['id'], named)
      named.any? { |reviewer| same_reviewer?(round, reviewer) }
    end

    def check_reviewers!(id, named)
      raise Error, "Finding #{id} must name the reviewers that reported it." unless
        named.is_a?(Array) && !named.empty?

      stray = named.reject { |reviewer| batch.any? { |index| same_reviewer?(rounds[index], reviewer) } }
      raise Error, "Finding #{id} names #{stray.join(', ')}, which did not review #{last_head}." if stray.any?
    end

    # Usage for one reviewer's round: under `usage` by reviewer, or at the top level for one round.
    def usage_for(content, reviewer)
      keys = %w[model tokens cost estimate]
      named = content['usage'].is_a?(Hash) && content['usage'].find { |name, _| name.casecmp?(reviewer) }&.last
      (named || (batch.one? ? content : {})).slice(*keys)
    end

    def joins?(round, head, reviewer) = head == last_head && !same_reviewer?(round, reviewer)

    def same_reviewer?(round, reviewer) = round['reviewer'].to_s.casecmp?(reviewer.to_s)
  end
end
