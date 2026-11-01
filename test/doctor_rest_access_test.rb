# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'

# Claude Code cloud sessions refuse GitHub GraphQL but allow REST, so doctor reads
# repository access over REST there, still never passes access it did not see, and
# reports the refusal that stops the commands needing GraphQL.
class DoctorRestAccessTest < Minitest::Test
  include DoctorHelper

  # The first line `gh repo view` printed in a Claude Code cloud session, trimmed before the proxy's route list.
  BLOCKED = ['', 'HTTP 403: GitHub GraphQL is not available from Claude Code sessions; use the REST API ' \
                 "(gh api repos/{owner}/{repo}/...). (https://api.github.com/graphql)\n", false].freeze
  REST = %w[gh api --hostname github.com].freeze

  def test_a_blocked_graphql_reads_write_access_over_rest_and_reports_the_refusal
    in_checkout do |root|
      calls = []
      report, = doctor(root:, runner: rest_runner(calls, permissions: { 'admin' => false, 'push' => true }))
      assert_includes line(report, 'Repository access'), '[HEALTHY]'
      assert_includes line(report, 'Repository access'), 'owner/repo is writable as WRITE (read over REST)'
      assert_includes line(report, 'GitHub GraphQL'), '[FAILED]'
      assert_includes calls, [*REST, 'repos/owner/repo']
    end
  end

  def test_a_blocked_graphql_with_read_only_rest_access_fails_the_access_check
    in_checkout do |root|
      report, = doctor(root:, runner: rest_runner([], permissions: { 'push' => false, 'pull' => true }))
      assert_includes line(report, 'Repository access'), '[FAILED]'
      assert_includes line(report, 'Repository access'), 'owner/repo is not writable (READ)'
    end
  end

  # A REST answer without a repository and permissions establishes nothing, and never crashes doctor.
  def test_a_rest_answer_of_the_wrong_shape_is_a_failed_check
    in_checkout do |root|
      ['null', '[]', '"text"', '{"full_name":"owner/repo"}', 'not json',
       '{"full_name":"owner/repo","permissions":{"admin":false,"push":false,"pull":false}}'].each do |body|
        report, = doctor(root:, runner: rest_runner([], body:))
        assert_includes line(report, 'Repository access'), '[FAILED]', body
      end
    end
  end

  # Only the GraphQL refusal switches to REST; another failure keeps its own report.
  def test_another_github_failure_does_not_try_rest
    in_checkout do |root|
      calls = []
      report, = doctor(root:, runner: rest_runner(calls, view: ['', "HTTP 401: Bad credentials\n", false]))
      assert_includes line(report, 'Repository access'), 'Bad credentials'
      assert_empty rest_calls(calls)
      refute_includes report, 'GitHub GraphQL'
    end
  end

  def test_an_origin_outside_github_blocks_without_rest
    in_checkout(origin: 'https://gitlab.com/owner/repo.git') do |root|
      calls = []
      report, = doctor(root:, runner: rest_runner(calls))
      assert_includes line(report, 'Repository access'), 'origin is not on github.com: gitlab.com'
      assert_empty rest_calls(calls)
    end
  end

  def test_a_checkout_without_an_origin_fails_the_access_check
    in_checkout(origin: nil) do |root|
      report, = doctor(root:, runner: rest_runner([]))
      assert_includes line(report, 'Repository access'), 'Cannot read origin'
    end
  end

  # A failed REST read is reported as it is; the GraphQL check claims nothing about REST.
  def test_a_failed_rest_read_keeps_its_own_reason
    in_checkout do |root|
      report, = doctor(root:, runner: rest_runner([], rest: ['', "HTTP 403: Resource not accessible\n", false]))
      assert_includes line(report, 'Repository access'), 'Resource not accessible'
      assert_equal "[FAILED] GitHub GraphQL — GitHub refuses GraphQL here\n", line(report, 'GitHub GraphQL')
    end
  end

  private

  def in_checkout(origin: 'https://github.com/owner/repo.git')
    Dir.mktmpdir do |dir|
      system('git', 'init', '--quiet', dir, exception: true)
      system('git', '-C', dir, 'remote', 'add', 'origin', origin, exception: true) if origin
      yield dir
    end
  end

  def rest_runner(calls, view: BLOCKED, permissions: { 'push' => true }, body: nil, rest: nil)
    fallback = stub_gh({})
    body ||= JSON.generate({ 'full_name' => 'owner/repo', 'permissions' => permissions }.compact)
    lambda do |argv, chdir = nil|
      calls << argv
      next view if argv.take(3) == %w[gh repo view]
      next rest || [body, '', true] if rest_calls([argv]).any?

      fallback.call(argv, chdir)
    end
  end

  def rest_calls(calls) = calls.select { |argv| argv.take(4) == REST }

  def line(report, name) = report.lines.find { it.include?(name) }.to_s
end
