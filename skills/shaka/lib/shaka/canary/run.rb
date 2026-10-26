# frozen_string_literal: true

require 'json'
require 'open3'
require 'time'
require 'tmpdir'
require_relative 'pulls'
require_relative 'report'

module Shaka
  module Canary
    # Runs one command and keeps its status. Tests pass a substitute.
    class Runner
      def capture(argv, chdir: nil)
        out, err, status = Open3.capture3(*argv, **(chdir ? { chdir: } : {}))
        { 'out' => out, 'err' => err, 'ok' => status.success? }
      end
    end

    # Reads actual agent-step starts, including failed and cancelled runs.
    class AttemptHistory
      def self.capture(runs, repository:, current:, runner: Runner.new)
        (runs + [{ 'databaseId' => current }]).uniq { |run| run.fetch('databaseId').to_s }.map do |run|
          started = start_for(run, repository, runner)
          run.merge('agent_started_at' => started&.iso8601)
        end
      end

      def self.start_for(run, repository, runner)
        path = "repos/#{repository}/actions/runs/#{run.fetch('databaseId')}/jobs?filter=all&per_page=100"
        result = runner.capture(['gh', 'api', '--paginate', '--slurp', path])
        raise "cannot read canary attempts: #{result['err']}" unless result['ok']

        Throttle.latest_start(JSON.parse(result['out']).flat_map { |page| page.fetch('jobs') })
      end
    end

    # Runs seam check, doctor, and validate in the canary checkout.
    class RepositoryChecks
      def initialize(env, runner)
        @env = env
        @runner = runner
      end

      def run(pull)
        return [] unless checkout(pull)['ok']

        [['seam check', seam_argv], ['doctor --brief', doctor_argv], ['validate', validate_argv]].map do |name, argv|
          ran = @runner.capture(argv, chdir: canary_dir)
          { 'name' => name, 'ok' => ran['ok'], 'detail' => clip("#{ran['out']}#{ran['err']}") }
        end
      end

      private

      def checkout(pull)
        @runner.capture(['gh', 'pr', 'checkout', pull['number'].to_s, '--repo', repo], chdir: canary_dir)
      end

      def seam_argv = [helper, 'seam', 'check', '--root', canary_dir, '--ref', default_sha]
      def doctor_argv = [helper, 'doctor', '--brief', '--root', canary_dir]
      def validate_argv = [File.join(canary_dir, '.agents/shaka/bin/validate')]

      def default_sha
        ran = @runner.capture(['git', '-C', canary_dir, 'rev-parse', 'origin/main'])
        raise "cannot resolve trusted canary base: #{clip(ran['err'])}" unless ran['ok']

        ran['out'].strip
      end

      def clip(text)
        line = text.to_s.lines.first.to_s.strip
        line.length > 180 ? "#{line[0, 180]}…" : line
      end

      def repo = @env.fetch('SHAKA_CANARY_REPO')
      def canary_dir = @env.fetch('CANARY_DIR')
      def helper = @env.fetch('SHAKA_HELPER')
    end

    # Names the Shaka commits this run covers and reads the previous run's summary comment.
    class Coverage
      def initialize(env, runner)
        @env = env
        @runner = runner
      end

      def commits
        previous = previous_sha
        range = previous ? "#{previous}..#{sha}" : sha
        argv = ['git', '-C', workspace, 'log', '--format=%h %s']
        argv << '-1' unless previous
        ran = @runner.capture([*argv, range])
        return [range] unless ran['ok']

        lines = ran['out'].lines.map(&:strip).reject(&:empty?)
        lines.empty? ? [sha] : lines
      end

      def comments(pulls, found)
        previous = found && Pulls.previous(pulls, found['number'])
        return [] unless previous

        bodies(previous['number'])
      end

      private

      def bodies(number)
        ran = @runner.capture(['gh', 'api', "repos/#{repo}/issues/#{number}/comments"])
        return [] unless ran['ok']

        parsed = JSON.parse(ran['out'])
        return [] unless parsed.is_a?(Array)

        parsed.map { |comment| comment['body'].to_s }
      rescue JSON::ParserError
        []
      end

      def previous_sha
        path = File.join(temp, 'canary-runs.json')
        return unless File.file?(path)

        runs = JSON.parse(File.read(path))
        exercised = runs.select { |run| exercised?(run) }
        exercised.max_by { |run| run.fetch('agent_started_at') }&.fetch('headSha')
      rescue JSON::ParserError
        nil
      end

      def exercised?(run) = run['agent_started_at'] && run['headSha'] && run['headSha'] != sha

      def sha = @env.fetch('GITHUB_SHA')
      def repo = @env.fetch('SHAKA_CANARY_REPO')
      def workspace = @env.fetch('GITHUB_WORKSPACE', Dir.pwd)
      def temp = @env.fetch('RUNNER_TEMP', Dir.tmpdir)
    end

    # Fetches the canary pull request, runs the repository checks, and writes the summary.
    class Collect
      def self.call(env, runner: Runner.new) = new(env, runner).call

      def initialize(env, runner)
        @env = env
        @runner = runner
      end

      def call
        pulls = list_pulls
        found = opened(pulls)
        result = Report.build(input_for(pulls, found))
        write(result)
        result
      rescue StandardError => e
        result = fallback(e)
        write(result)
        result
      end

      private

      def list_pulls
        listed = @runner.capture(['gh', 'pr', 'list', '--repo', repo, '--state', 'all', '--limit', '30',
                                  '--json', 'number,state,createdAt,title,body,url,headRefName,isCrossRepository'])
        raise "gh pr list failed: #{listed['err'].to_s.lines.first.to_s.strip}" unless listed['ok']

        parsed = JSON.parse(listed['out'])
        parsed.is_a?(Array) ? Pulls.canaries(parsed) : []
      end

      def opened(pulls)
        Pulls.newest_since(Pulls.for_run(pulls, @env['CANARY_BRANCH']), started_at)
      end

      def input_for(pulls, found)
        coverage = Coverage.new(@env, @runner)
        { 'pulls' => pulls, 'started_at' => started_at.iso8601, 'finished_at' => Time.now.utc.iso8601,
          'shaka_sha' => @env.fetch('GITHUB_SHA'), 'shaka_repo' => repository,
          'run_url' => run_url, 'commits' => coverage.commits, 'keep' => keep,
          'command_checks' => found ? RepositoryChecks.new(@env, @runner).run(found) : [],
          'previous_comments' => coverage.comments(pulls, found), 'branch' => @env['CANARY_BRANCH'] }
      end

      def write(result)
        File.write(File.join(temp, 'canary-summary.md'), result.fetch('summary'))
        File.write(File.join(temp, 'canary-result.json'), JSON.generate(result))
        path = @env['GITHUB_STEP_SUMMARY']
        File.write(path, "#{result.fetch('summary')}\n", mode: 'a') if path
      end

      def started_at
        path = File.join(temp, 'canary-started-at')
        return Time.now.utc unless File.file?(path)

        Time.iso8601(File.read(path).strip)
      end

      def repo = @env.fetch('SHAKA_CANARY_REPO')
      def temp = @env.fetch('RUNNER_TEMP', Dir.tmpdir)
      def keep = Integer(@env.fetch('SHAKA_CANARY_KEEP', Pulls::KEEP), exception: false) || Pulls::KEEP
      def repository = @env.fetch('GITHUB_REPOSITORY', 'shakacode/shaka')

      def run_url
        server = @env.fetch('GITHUB_SERVER_URL', 'https://github.com')
        "#{server}/#{repository}/actions/runs/#{@env['GITHUB_RUN_ID']}"
      end

      def fallback(error)
        summary = Summary.render(
          'ok' => false, 'shaka_sha' => @env.fetch('GITHUB_SHA', 'unknown'),
          'shaka_repo' => repository,
          'checks' => [{ 'name' => 'collect', 'ok' => false, 'detail' => error.message }],
          'spend' => 'UNKNOWN', 'previous_spend' => 'UNKNOWN', 'commits' => [@env.fetch('GITHUB_SHA', 'unknown')],
          'run_url' => run_url,
          'diff' => 'No previous canary PR body.'
        )
        { 'ok' => false, 'summary' => summary, 'number' => nil, 'close' => [] }
      end
    end

    # Posts the summary on the canary pull request and closes older ones.
    class Publish
      NOTE = "#{Summary::IDENTITY}\n\nClosed by the Shaka canary cleanup. The newest runs stay open.\n".freeze

      def self.call(env, runner: Runner.new) = new(env, runner).call

      def initialize(env, runner)
        @env = env
        @runner = runner
      end

      def call
        result = JSON.parse(File.read(result_path))
        comment(result) && close(result) ? 0 : 1
      end

      private

      def comment(result)
        return true unless result['number']

        @runner.capture(['gh', 'pr', 'comment', result['number'].to_s, '--repo', repo, '--body-file',
                         summary_path])['ok']
      end

      def close(result)
        Array(result['close']).all? do |number|
          @runner.capture(['gh', 'pr', 'close', number.to_s, '--repo', repo, '--comment', NOTE])['ok']
        end
      end

      def repo = @env.fetch('SHAKA_CANARY_REPO')
      def temp = @env.fetch('RUNNER_TEMP', Dir.tmpdir)
      def result_path = File.join(temp, 'canary-result.json')
      def summary_path = File.join(temp, 'canary-summary.md')
    end
  end
end
