# frozen_string_literal: true

require_relative '../../../../skills/shaka/lib/shaka/post_implementation/risk'
require_relative 'risk_replay'

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
      # { 'high' => areas, 'medium' => areas, 'max_risk' => level }, keyed by arm; plan: the comparison's
      # planned 'arms', 'cases' and 'repeats', so an arm or run a stopped replay never reached counts as unattempted.
      def score(records:, cases:, paths:, settings:, plan:)
        by_arm = records.group_by { |record| record.fetch('arm') }
        plan.fetch('arms').keys.to_h do |arm|
          [arm, arm_score(by_arm.fetch(arm, []), cases, paths, settings.fetch(arm), plan)]
        end
      end

      def arm_score(runs, cases, paths, settings, plan)
        planned = planned_cases(runs, cases, paths, settings, plan)
        { 'runs' => runs.size, 'failed' => runs.count { |run| rating(run).nil? },
          'unattempted' => planned.values.sum { |entry| entry.fetch('unattempted') }, **costs(runs),
          'configured_max_risk' => settings.fetch('max_risk'), 'cases' => planned }
      end

      # A case whose repeats all failed or never ran still appears.
      def planned_cases(runs, cases, paths, settings, plan)
        by_case = runs.group_by { |run| run.fetch('case') }
        plan.fetch('cases').to_h do |id|
          rated, counts = attempt_counts(by_case.fetch(id, []), plan.fetch('repeats'))
          [id, counts.merge(case_score(rated, cases.fetch(id), paths[id], settings))]
        end
      end

      def attempt_counts(attempts, repeats)
        rated = attempts.select { |run| rating(run) }
        [rated, { 'attempted' => attempts.size, 'unattempted' => [repeats - attempts.size, 0].max,
                  'rated' => rated.size }]
      end

      # Agreement needs at least two ratings. Merge reads a rating only from a ready checkpoint, so the gate
      # counts a report that is not ready as unknown, while agreement still uses the reviewer's rating.
      def case_score(rated, row, paths, settings)
        ratings = rated.map { |run| rating(run) }
        gated = rated.map { |run| gate_rating(run) }
        reference = row['reference']
        { 'ratings' => ratings, 'consistent' => ratings.size < 2 ? 'UNKNOWN' : ratings.uniq.one?,
          'published' => row['published'], 'matches_published' => ratings.count(row['published']),
          'reference' => reference || 'UNKNOWN', 'against_reference' => against(ratings, reference),
          'risk_gate' => THRESHOLDS.to_h { |max| [max, gate([gated, ratings], reference, paths, settings, max)] } }
      end

      def gate_rating(run) = run.dig('result', 'ready') ? rating(run) : 'unknown'

      # Underestimates are the costly error: a rating below the maintainer's can pass the risk gate.
      def against(ratings, reference)
        return 'UNKNOWN' unless reference

        ratings.map { |rating| compare(rating, reference) }.tally
      end

      # An unknown rating is no judgment, so it is counted apart rather than credited or blamed.
      def compare(rating, reference)
        return 'abstain' if rating == 'unknown'
        return 'match' if rating == reference

        rank(rating) < rank(reference) ? 'under' : 'over'
      end

      # unknown counts as high, as the checkpoint treats it.
      def rank(rating) = LEVELS.index(rating) || (LEVELS.size - 1)

      # Passes and holds follow merge, readiness included; the errors against the reference come from the
      # reviewer's rating alone, so a hold for an unready checkpoint is not blamed on the rating.
      def gate((gated, ratings), reference, paths, settings, max)
        shipped = gated.map { |rating| passes?(rating, paths, settings, max) }
        result = { 'passes' => shipped.count(true), 'holds' => shipped.count(false) }
        return result.merge('wrong_passes' => 'UNKNOWN', 'needless_holds' => 'UNKNOWN') unless reference

        rated = ratings.map { |rating| passes?(rating, paths, settings, max) }
        wanted = passes?(reference, paths, settings, max)
        result.merge('wrong_passes' => wanted ? 0 : rated.count(true),
                     'needless_holds' => wanted ? rated.count(false) : 0)
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
        result.dig('risk', 'rating') if result['status'] == 'completed' && RiskReplay.rated?(result)
      end
    end
  end
end
