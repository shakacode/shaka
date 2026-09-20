# frozen_string_literal: true

require_relative 'prose'

module Shaka
  module Writing
    # Reports the style signals the baseline names and never fails on any of them.
    # A gated metric teaches the writer to dodge the metric: ban em dashes and comma
    # splices appear. These lists are the repository's own, so a false positive is
    # cheap to correct here.
    class Advisory
      HEDGES = %w[may might could perhaps possibly arguably somewhat relatively fairly quite rather
                  generally typically essentially basically simply just actually really very seems
                  appears likely probably].freeze
      FILLERS = ['in order to', 'it is worth noting', 'it should be noted', 'note that',
                 'needless to say', 'at the end of the day', 'it is important to', 'as mentioned',
                 'simply put', 'in summary', 'that being said'].freeze
      DIFF_VERBS = %w[adds makes updates fixes removes changes introduces implements refactors renames
                      moves bumps improves replaces enables allows ensures supports handles adjusts].freeze
      DIFF_OPENERS = ['this change', 'this pr', 'this commit', 'this patch', 'this diff'].freeze
      EMPHASIS = /(\*\*|__)(?=\S)(?:(?!\1).)+\1/m
      SENTENCE_END = /(?<=[.!?])\s+/

      def initialize(markdown)
        @markdown = markdown
      end

      def lines
        ["reading grade #{grade}; the baseline targets grade 8 in broad prose and grade 12 in technical prose",
         "opening sentence: #{opening_note}",
         "hedging #{per_hundred(hedges)} and decorative emphasis #{per_hundred(emphasis)} per 100 words",
         "filler openers: #{fillers.empty? ? 'none' : fillers.join(', ')}"]
      end

      private

      def text = @text ||= Prose.text(@markdown)
      def words = @words ||= Prose.words(@markdown)
      def sentences = @sentences ||= split(text)

      def split(source) = source.split(SENTENCE_END).map(&:strip).reject(&:empty?)

      # Flesch-Kincaid over a short summary is a rough guide, which is why it only prints.
      def grade
        return 'UNKNOWN' if words.empty? || sentences.empty?

        format('%.1f', (0.39 * sentence_length) + (11.8 * word_length) - 15.59)
      end

      def sentence_length = words.size.fdiv(sentences.size)
      def word_length = syllables.fdiv(words.size)

      def syllables = words.sum { |word| syllables_in(word) }

      def syllables_in(word)
        stem = word.delete("'")
        stem = stem.delete_suffix('e') if stem.length > 2 && !stem.end_with?('le')
        [stem.scan(/[aeiouy]+/).size, 1].max
      end

      # The identity line and headings are the helper's own text, not the writer's summary.
      def opening
        @opening ||= split(text.lines.reject { |line| line.strip.empty? || line.start_with?('🤖', '#') }.join)
                     .first.to_s
      end

      def opening_note
        start = opening.downcase
        verb = start[/[a-z']+/].to_s
        return 'none found' if verb.empty?
        return "diff-shaped; it opens with the bare verb \"#{verb}\"" if DIFF_VERBS.include?(verb)

        filler = DIFF_OPENERS.find { |phrase| start.start_with?(phrase) }
        filler ? "diff-shaped; it opens with \"#{filler}\" instead of the outcome" : 'opens with a subject'
      end

      def hedges = words.count { |word| HEDGES.include?(word) }

      def emphasis = text.scan(EMPHASIS).size

      def fillers
        opener = text.downcase
        FILLERS.select { |phrase| opener.include?(phrase) }
      end

      def per_hundred(count)
        return 'UNKNOWN' if words.empty?

        format('%.1f', count.fdiv(words.size) * 100)
      end
    end
  end
end
