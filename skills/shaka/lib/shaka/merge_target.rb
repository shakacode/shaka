# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_review_floor'

module Shaka
  # The commit and branch a merge run is allowed to land, named before any gate is read.
  #
  # A merge can reach the wrong branch two ways, and neither implies the other. The pull
  # request may never have targeted the branch the change was validated against, because it
  # was retargeted before this run or because a stated base was never applied to a pull
  # request the task adopted. Or its target may move while this run reads gates. Both live
  # here so neither can be dropped without the other being obvious. A head past the size limits,
  # or changing files above the Auto review floor, also needs a human to confirm it before an
  # agent may land it.
  class MergeTarget
    def self.required!(head, base, limits, review_floor = nil)
      raise Error, 'Expected a full commit SHA' unless head.is_a?(String) && head.match?(/\A[0-9a-f]{40}\z/)
      return new(head, base, limits, review_floor || MergeReviewFloor.new) if base.is_a?(String) && !base.strip.empty?

      raise Error, 'Expected the base branch the change was validated against'
    end

    def initialize(head, base, limits, review_floor)
      @head = head
      @base = base
      @limits = limits
      @review_floor = review_floor
    end

    def validated!(pull, github)
      unless pull['baseRefName'] == @base
        raise Error, "PR targets #{pull['baseRefName'].inspect}, not the validated base #{@base.inspect}"
      end

      gates!(pull, github)
    end

    # The size and changed files are rechecked so what gates submission comes from the last read;
    # a rewritten base can change the diff without moving the head.
    def unchanged!(initial, current, github)
      unless current['baseRefName'] == initial['baseRefName']
        raise Error, 'PR base changed; refresh verification and walkthrough'
      end

      gates!(current, github)
    end

    private

    # One confirmation passes both gates, so a refusal names every reason the user would be confirming.
    def gates!(pull, github)
      reasons = [-> { @limits.verify!(pull, @head) }, -> { @review_floor.verify!(github, @head) }].filter_map do |gate|
        gate.call
        nil
      rescue Error => e
        e.message
      end
      raise Error, reasons.join(' Also: ') unless reasons.empty?
    end
  end
end
