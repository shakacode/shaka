# frozen_string_literal: true

require 'open3'
require_relative '../../../../skills/shaka/lib/shaka/configuration'
require_relative '../../../../skills/shaka/lib/shaka/post_implementation/risk'
require_relative 'review_replay_fixture'

module Shaka
  module Evaluation
    # The inputs a risk replay reads outside its fixtures: each arm's committed policy and the tools that rated.
    module RiskReplayInputs
      CLIS = { 'claude-code' => 'claude', 'codex' => 'codex' }.freeze

      module_function

      # Each arm's committed risk areas and threshold, read with the fixture's Git isolation, so a replacement
      # ref or redirected repository cannot substitute another policy for the recorded commit.
      def policy(source, ref)
        isolated_git do
          config = Configuration.trusted(root: source, ref:, candidate_commands: false)
          high, medium = PostImplementationRisk.areas(config)
          { 'high' => high, 'medium' => medium, 'max_risk' => PostImplementationRisk.max_risk(config) }
        end
      end

      def isolated_git
        saved = ReviewReplayFixture::GIT_ENVIRONMENT.keys.to_h { |name| [name, ENV.fetch(name, nil)] }
        ENV.update(ReviewReplayFixture::GIT_ENVIRONMENT)
        yield
      ensure
        ENV.update(saved)
      end

      # The installed helper supplies the rating rubric and report parser, and the provider CLI runs the model,
      # so a record names both; UNKNOWN when either cannot be read.
      def tools(helper, host)
        { 'helper' => helper_revision(File.expand_path('../../..', File.dirname(helper))),
          'cli' => version(CLIS.fetch(host)) }
      end

      def helper_revision(root)
        revision, ok = capture('git', '-C', root, 'rev-parse', 'HEAD')
        return 'UNKNOWN' unless ok

        changes, = capture('git', '-C', root, 'status', '--porcelain')
        changes.empty? ? revision : "#{revision}+modified"
      end

      def version(cli)
        output, ok = capture(cli, '--version')
        ok ? output.lines.first.to_s.strip : 'UNKNOWN'
      end

      def capture(*command)
        output, status = Open3.capture2e(ReviewReplayFixture::GIT_ENVIRONMENT, *command)
        [output.strip, status.success?]
      rescue SystemCallError
        ['', false]
      end
    end
  end
end
