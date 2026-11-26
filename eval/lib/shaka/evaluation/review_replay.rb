# frozen_string_literal: true

require 'tmpdir'
require_relative 'budget'
require_relative 'native_usage'
require_relative 'review_replay_fixture'
require_relative 'review_replay_login'
require_relative 'review_replay_records'

module Shaka
  module Evaluation
    # Runs each historical full diff twice, then leaves evidence for blinded human scoring.
    class ReviewReplay
      include ReviewReplayLogin
      include ReviewReplayRecords

      HOSTS = { 'anthropic/claude' => 'claude-code', 'openai/codex' => 'codex' }.freeze

      def initialize(options)
        @options = options
        @source, @helper, @reviewer, @directory = options.values_at(:source, :helper, :reviewer, :directory)
        @host = HOSTS.fetch(@reviewer) { raise ArgumentError, 'Choose anthropic/claude or openai/codex' }
      end

      def run(rows)
        validate_settings_change
        @environment = ReviewReplayFixture::GIT_ENVIRONMENT.merge(CREDENTIALS)
        Dir.mktmpdir('review-', @directory) do |scratch|
          @scratch = scratch
          start_budget unless @options[:preview]
          rows.each_with_index { |row, index| replay_pair(row, index) }
        end
      end

      private

      def validate_settings_change
        baseline, candidate = @options.values_at(:baseline, :candidate).map { |arm| arm.fetch(:criteria) }
        snapshots = [baseline, candidate].uniq.map { |ref| review_settings(ref) }
        return if snapshots.one?

        criteria, settings = snapshots.transpose
        raise ArgumentError, 'Keep AGENTS.md criteria unchanged between prompt arms' unless criteria.uniq.one?
        raise ArgumentError, 'Both commits supply the same repository settings files' if settings.uniq.one?
      end

      def review_settings(ref)
        files = ReviewReplayFixture.entries(@source, ref)
        criteria, other = files.partition { |entry| ReviewReplayFixture.agents_path?(entry.split("\t", 2).last) }
        [criteria, other.grep(%r{\t\.agents/shaka/})]
      end

      def start_budget
        verify_login
        @budget = Budget.new(directory: @options.fetch(:budget), kind: 'pr',
                             **@options.slice(:limits, :scope, :cap))
      end

      def replay_pair(row, index)
        arms = %i[baseline candidate]
        arms.reverse! if index.odd?
        arms.each { |arm| replay(row, arm) }
      end

      def replay(row, arm)
        Dir.mktmpdir('checkout-', @scratch) do |root|
          criteria = @options.fetch(arm).fetch(:criteria)
          fixture = ReviewReplayFixture.new(source: @source, root:, row:)
          snapshot = fixture.prepare(criteria)
          return puts("#{row.fetch('id')} #{arm} fixture ready") if @options[:preview]

          execute(row, arm, root, snapshot)
        end
      end

      def execute(row, arm, root, snapshot)
        arguments = review_arguments(row, arm, root, snapshot)
        id = @budget.reserve
        record, status = capture_record(arguments, root, id)
        digest = save_run(id, row.fetch('id'), arm, record)
        complete = status.success? && completed?(record.fetch('result'), row)
        finish(id, record.fetch('usage'), digest, complete)
      end

      def completed?(result, row)
        result['status'] == 'completed' && result['head'] == row.fetch('head') && result['reviewer'] == @reviewer
      end

      def finish(id, usage, digest, complete)
        claim = usage.fetch('cache_neutral_dollars')
        raise IOError, "Review usage is unknown; reconcile budget reservation #{id}" if claim == 'UNKNOWN'

        over = @budget.settle(id:, dollars: claim, digest:)
        raise Budget::Stopped, 'cap_exceeded' if over
        raise IOError, "Review incomplete; see private record #{id}" unless complete
      end

      def review_arguments(row, arm, root, snapshot)
        chosen = @options.fetch(arm)
        arguments = ['review', 'run', '--root', root, '--base', row.fetch('base'), '--head', row.fetch('head'),
                     '--reviewer', @reviewer, '--criteria-ref', snapshot, '--timeout-seconds', '300',
                     '--model', chosen.fetch(:model)]
        arguments.push('--effort', @options.fetch(:effort)) if @options[:effort]
        arguments
      end

      def usage_for(result)
        return { 'cache_neutral_dollars' => 0, 'billed_dollars' => 0 } if result['attempted'] == false
        return { 'cache_neutral_dollars' => 'UNKNOWN', 'billed_dollars' => 'UNKNOWN' } unless result['usage']

        @native_usage ||= NativeUsage.new(helper: @helper, rate_root: @source)
        @native_usage.read(host: @host, files: [result.fetch('usage')], print_result: @host == 'claude-code')
      end
    end
  end
end
