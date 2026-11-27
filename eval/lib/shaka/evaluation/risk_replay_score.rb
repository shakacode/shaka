# frozen_string_literal: true

require_relative '../../../../skills/shaka/lib/shaka/post_implementation/risk'
require_relative '../../../../skills/shaka/lib/shaka/post_implementation_report'

module Shaka
  module Evaluation
    # Scores replayed checkpoint ratings. The rating is the model's judgment; the risk gate applies Shaka's
    # deterministic risk areas and merge.auto_merge_max_risk to it. Merge also checks verification adequacy,
    # size limits, hold labels and required checks, which this score leaves out, so a gate pass is not a merge.
    module RiskReplayScore
      LEVELS = PostImplementationRisk::LEVELS
      THRESHOLDS = %w[low medium].freeze

      module_function

      # records: saved run records of one comparison; cases: frozen rows by id; paths: changed files by case id;
      # settings: each arm's risk areas and threshold from its settings commit, as
      # { 'high' => areas, 'medium' => areas, 'max_risk' => level }, keyed by arm.
      def score(records:, cases:, paths:, settings:)
        records.group_by { |record| record.fetch('arm') }.to_h do |arm, runs|
          [arm, arm_score(runs, cases, paths, settings.fetch(arm))]
        end
      end

      def arm_score(runs, cases, paths, settings)
        by_case = runs.group_by { |run| run.fetch('case') }
        { 'runs' => runs.size, 'failed' => runs.count { |run| rating(run).nil? }, **costs(runs),
          'configured_max_risk' => settings.fetch('max_risk'),
          'cases' => by_case.to_h { |id, attempts| [id, case_score(attempts, cases.fetch(id), paths[id], settings)] } }
      end

      # A case whose repeats all failed still appears, and agreement needs at least two ratings.
      def case_score(attempts, row, paths, settings)
        ratings = attempts.filter_map { |run| rating(run) }
        reference = row['reference']
        { 'attempted' => attempts.size, 'rated' => ratings.size, 'ratings' => ratings,
          'consistent' => ratings.size < 2 ? 'UNKNOWN' : ratings.uniq.one?,
          'published' => row['published'], 'matches_published' => ratings.count(row['published']),
          'reference' => reference || 'UNKNOWN', 'against_reference' => against(ratings, reference),
          'risk_gate' => THRESHOLDS.to_h { |max| [max, gate(ratings, reference, paths, settings, max)] } }
      end

      # Underestimates are the costly error: a rating below the maintainer's can pass the risk gate.
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

      def gate(ratings, reference, paths, settings, max)
        decisions = ratings.map { |rating| passes?(rating, paths, settings, max) }
        result = { 'passes' => decisions.count(true), 'holds' => decisions.count(false) }
        return result.merge('wrong_passes' => 'UNKNOWN', 'needless_holds' => 'UNKNOWN') unless reference

        wanted = passes?(reference, paths, settings, max)
        result.merge('wrong_passes' => wanted ? 0 : decisions.count(true),
                     'needless_holds' => wanted ? decisions.count(false) : 0)
      end

      def passes?(rating, paths, settings, max)
        level = PostImplementationRisk.assess(rating, settings.fetch('high'), paths, settings.fetch('medium'))
        PostImplementationRisk.within?(level.fetch('level'), max)
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
