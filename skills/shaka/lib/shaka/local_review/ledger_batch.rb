# frozen_string_literal: true

require_relative '../error'

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

    def recorded_index(reviewer, candidates = batch)
      raise Error, 'The ledger has no round to record.' if candidates.empty?
      return candidates.last if reviewer.nil? && candidates.one?
      raise Error, "Several reviewers read #{last_head}; pass --reviewer to record one." if reviewer.nil?

      candidates.find { |index| same_reviewer?(rounds[index], reviewer) } ||
        raise(Error, "No round by #{reviewer} reviewed #{last_head}.")
    end

    # Another reviewer may join the last batch; any other repeat of a commit needs a fix first.
    def check_new_head!(head, reviewer)
      reviewed = rounds.index { |round| round['head'] == head && !joins?(round, head, reviewer) }
      raise Error, "Round #{reviewed + 1} already reviewed #{head}; commit the fix first." if reviewed
    end

    def joins?(round, head, reviewer) = head == last_head && !same_reviewer?(round, reviewer)

    def same_reviewer?(round, reviewer) = round['reviewer'].to_s.casecmp?(reviewer.to_s)
  end
end
