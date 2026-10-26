# frozen_string_literal: true

require_relative 'pulls'
require_relative 'body'
require_relative 'gate'
require_relative 'text'

module Shaka
  module Canary
    # Turns the workflow's gathered JSON into the check result and the summary.
    module Report
      COMMANDS = ['seam check', 'doctor --brief', 'validate'].freeze

      module_function

      MISSING_PR = 'no canary pull request opened after the run started'

      def build(input)
        context = context_for(input)
        payload(input, context)
      end

      def context_for(input)
        found = opened(input)
        body_issues = found ? BodyCheck.issues(found['body'].to_s) : [MISSING_PR]
        command_issues = commands(input, found)
        { found:, previous: found && Pulls.previous(input.fetch('pulls'), found['number']),
          body_issues:, command_issues:, passed: body_issues.empty? && command_issues.empty? }
      end

      def opened(input)
        Pulls.newest_since(input.fetch('pulls'), Time.iso8601(input.fetch('started_at')))
      end

      def commands(input, found)
        return ['command checks did not run because no pull request opened'] unless found

        checks = Array(input['command_checks'])
        missing = COMMANDS - checks.map { |check| check['name'] }
        missing.map { |name| "missing command check #{name}" } + failed(checks)
      end

      def failed(checks)
        checks.reject { |check| check['ok'] == true }.map { |check| "#{check['name']} failed: #{check['detail']}" }
      end

      def payload(input, context)
        found = context.fetch(:found)
        spend = Spend.from(found && found['body'])
        { 'ok' => context.fetch(:passed), 'summary' => Summary.render(summary_report(input, context, spend)),
          'number' => found && found['number'], 'close' => close_numbers(input, found) }
      end

      def close_numbers(input, found)
        keep = input['keep'].is_a?(Integer) && input['keep'].positive? ? input['keep'] : Pulls::KEEP
        Pulls.closable(input.fetch('pulls'), keep: keep, current: found && found['number']).map do |pull|
          pull['number']
        end
      end

      def summary_report(input, context, spend)
        base(input, context).merge(proof(input, context, spend))
      end

      def base(input, context)
        { 'ok' => context.fetch(:passed), 'shaka_sha' => input.fetch('shaka_sha'),
          'shaka_repo' => input.fetch('shaka_repo'), 'run_url' => input['run_url'],
          'commits' => input['commits'], 'canary_pr_url' => url_for(context) }
      end

      def proof(input, context, spend)
        { 'spend' => spend, 'checks' => rows_for(context), 'previous_spend' => Spend.from(body_of(context, :previous)),
          'elapsed_seconds' => elapsed(input), 'previous_elapsed_seconds' => previous_elapsed(input),
          'diff' => BodyDiff.report(body_of(context, :previous), body_of(context, :found)) }
      end

      def url_for(context)
        found = context.fetch(:found)
        found && found['url']
      end

      def rows_for(context) = check_rows(context.fetch(:body_issues), context.fetch(:command_issues))

      def body_of(context, key)
        pull = context.fetch(key)
        pull && pull['body']
      end

      def check_rows(body_issues, command_issues)
        [{ 'name' => 'description', 'ok' => body_issues.empty?, 'detail' => detail(body_issues, 'renders') },
         { 'name' => 'commands', 'ok' => command_issues.empty?, 'detail' => detail(command_issues, 'passed') }]
      end

      def detail(issues, ok_text) = issues.empty? ? ok_text : issues.join('; ')

      def elapsed(input)
        started = Time.iso8601(input.fetch('started_at'))
        finished = Time.iso8601(input.fetch('finished_at'))
        seconds = (finished - started).round
        seconds.negative? ? nil : seconds
      end

      def previous_elapsed(input)
        marker = Summary.elapsed_marker(input['previous_comments'])
        return marker unless marker.match?(/\A\d+\z/)

        Integer(marker)
      end
    end
  end
end
