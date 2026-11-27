# frozen_string_literal: true

require_relative '../../../../skills/shaka/lib/shaka/post_implementation/risk'
require_relative '../../../../skills/shaka/lib/shaka/post_implementation_report'

module Shaka
  module Evaluation
    # Scores replayed checkpoint ratings. The rating is the model's judgment; the merge decision applies Shaka's
    # deterministic risk areas and auto_merge_max_risk to it, so both are reported separately.
    module RiskReplayScore
      LEVELS = PostImplementationRisk::LEVELS
      THRESHOLDS = %w[low medium].freeze

      module_function

      # records: saved run records; cases: frozen rows by id; paths: changed files by case id; areas: the
      # [high, medium] risk areas each arm's settings commit configures, keyed by arm.
      def score(records:, cases:, paths:, areas:)
        records.group_by { |record| record.fetch('arm') }.to_h do |arm, runs|
          [arm, arm_score(runs, cases, paths, areas.fetch(arm))]
        end
      end

      def arm_score(runs, cases, paths, areas)
        by_case = ratings_by_case(runs)
        { 'runs' => runs.size, 'failed' => runs.size - by_case.values.sum(&:size), **costs(runs),
          'cases' => by_case.to_h { |id, ratings| [id, case_score(ratings, cases.fetch(id), paths[id], areas)] } }
      end

      def ratings_by_case(runs)
        rated = runs.filter_map { |run| rating(run)&.then { |value| [run.fetch('case'), value] } }
        rated.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
      end

      def case_score(ratings, row, paths, areas)
        reference = row['reference']
        { 'ratings' => ratings, 'consistent' => ratings.uniq.one?,
          'published' => row['published'], 'matches_published' => ratings.count(row['published']),
          'reference' => reference || 'UNKNOWN', 'against_reference' => against(ratings, reference),
          'auto' => THRESHOLDS.to_h { |max| [max, auto(ratings, reference, paths, areas, max)] } }
      end

      # Underestimates are the costly error: a rating below the maintainer's can let Auto merge it.
      def against(ratings, reference)
        return 'UNKNOWN' unless reference

        ratings.map { |rating| compare(rating, reference) }.tally
      end

      def compare(rating, reference)
        return 'match' if rating == reference

        rank(rating) < rank(reference) ? 'under' : 'over'
      end

      # unknown counts as high, as the checkpoint treats it.
      def rank(rating) = LEVELS.index(rating) || (LEVELS.size - 1)

      def auto(ratings, reference, paths, areas, max)
        decisions = ratings.map { |rating| merges?(rating, paths, areas, max) }
        result = { 'merges' => decisions.count(true), 'holds' => decisions.count(false) }
        return result.merge('wrong_merges' => 'UNKNOWN', 'needless_holds' => 'UNKNOWN') unless reference

        wanted = merges?(reference, paths, areas, max)
        result.merge('wrong_merges' => wanted ? 0 : decisions.count(true),
                     'needless_holds' => wanted ? decisions.count(false) : 0)
      end

      def merges?(rating, paths, areas, max)
        level = PostImplementationRisk.assess(rating, areas.first, paths, areas.last).fetch('level')
        PostImplementationRisk.within?(level, max)
      end

      def costs(runs)
        { 'dollars' => total(runs) { |run| run.dig('usage', 'cache_neutral_dollars') },
          'duration_ms' => total(runs) { |run| run.dig('result', 'duration_ms') } }
      end

      # Missing usage or timing makes the total UNKNOWN rather than an undercount.
      def total(runs, &)
        values = runs.map(&)
        values.all?(Numeric) ? values.sum : 'UNKNOWN'
      end

      def rating(run)
        result = run['result'] || {}
        rating = result.dig('risk', 'rating')
        result['status'] == 'completed' && PostImplementationReport::RISK.include?(rating) ? rating : nil
      end
    end
  end
end
