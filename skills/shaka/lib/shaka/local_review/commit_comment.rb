# frozen_string_literal: true

require_relative 'comment'

module Shaka
  # One timeline entry, validated against the complete loop so slicing cannot hide invalid fixes.
  class LocalReviewCommitComment < LocalReviewComment
    def initialize(content, head:, subject:, **)
      super(content, **)
      @history = @rounds
      @rounds = @history.select { |round| round.head == head }
      @before = @history.take_while { |round| round.head != head }
      @subject = subject
    end

    def key = "local-review-#{@rounds.last.head}"

    def render
      blocks = [TITLE, reason, table, *fallback_notice, *settings_notice, *bound,
                '## Findings', LocalReviewTriage.new(@rounds.last.head, @rounds, @links).render(fixed_before),
                *LocalReviewTriage.details(@rounds, @links, fixed_before), @rounds.last.attestation]
      "#{blocks.join("\n\n")}\n"
    end

    private

    def reason
      fixes = previous_fixes
      return "**Why this commit exists:** #{@subject.call(@rounds.last.head)}" if fixes.empty?

      lines = fixes.map { |finding| "- `#{finding.id}`: #{finding.summary}" }
      "**Why this commit exists:** fixes findings from the previous triage.\n\n#{lines.join("\n")}"
    end

    def previous_fixes
      previous_batch.flat_map(&:findings).uniq(&:id).select do |finding|
        finding.fixed? && finding.commit == @rounds.last.head
      end
    end

    def previous_batch = @before.select { |round| round.head == @before.last&.head }

    def fixed_before
      @before.chunk(&:head).each_with_object({}) do |(_, batch), fixed|
        LocalReviewTriage.remember_fixes(batch, fixed)
      end
    end

    # Only the final entry can announce that the loop reached its bound.
    def bound
      @rounds.last.head == @history.last.head ? LocalReviewBound.new(@history, @max_rounds).lines : []
    end
  end
end
