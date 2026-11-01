# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'

# Claude Code cloud sessions refuse GitHub GraphQL but allow REST, so doctor reads
# repository access over REST there and still never passes access it did not see.
class DoctorRestAccessTest < Minitest::Test
  include DoctorHelper

  BLOCKED = ['', "HTTP 403: GitHub GraphQL is not available from this session (https://api.github.com/graphql)\n",
             false].freeze

  def test_a_blocked_graphql_reads_write_access_over_rest
    calls = []
    report, = doctor(runner: rest_runner(calls, permissions: { 'admin' => false, 'push' => true }))
    assert_includes access_line(report), '[HEALTHY]'
    assert_includes access_line(report), 'owner/repo is writable as WRITE (read over REST'
    assert_includes calls, ['gh', 'api', "repos/#{origin_identity}"]
  end

  def test_a_blocked_graphql_with_read_only_rest_access_blocks
    report, blocked = doctor(runner: rest_runner([], permissions: { 'push' => false, 'pull' => true }))
    assert_includes access_line(report), 'owner/repo is not writable (READ)'
    assert blocked
  end

  # A REST answer without permissions establishes nothing.
  def test_a_rest_answer_without_permissions_blocks
    report, blocked = doctor(runner: rest_runner([], permissions: nil))
    assert_includes access_line(report), 'did not report a repository and a permission'
    assert blocked
  end

  # Only the GraphQL refusal switches to REST; another failure keeps its own report.
  def test_another_github_failure_does_not_try_rest
    calls = []
    report, blocked = doctor(runner: rest_runner(calls, view: ['', "HTTP 401: Bad credentials\n", false]))
    assert_includes access_line(report), 'Bad credentials'
    refute(calls.any? { |argv| argv.take(2) == %w[gh api] && argv[2].start_with?('repos/') })
    assert blocked
  end

  def test_an_origin_outside_github_blocks_without_rest
    Dir.mktmpdir do |dir|
      system('git', 'init', '--quiet', dir, exception: true)
      system('git', '-C', dir, 'remote', 'add', 'origin', 'https://gitlab.com/owner/repo.git', exception: true)
      calls = []
      report, blocked = doctor(root: dir, runner: rest_runner(calls))
      assert_includes access_line(report), 'origin is not on github.com: gitlab.com'
      assert_empty(calls.select { |argv| argv.take(2) == %w[gh api] && argv[2].start_with?('repos/') })
      assert blocked
    end
  end

  private

  def rest_runner(calls, view: BLOCKED, permissions: { 'push' => true })
    fallback = stub_gh({})
    lambda do |argv, chdir = nil|
      calls << argv
      next view if argv.take(3) == %w[gh repo view]
      next rest_repository(permissions) if argv.take(2) == %w[gh api] && argv[2].start_with?('repos/')

      fallback.call(argv, chdir)
    end
  end

  def rest_repository(permissions)
    [JSON.generate({ 'full_name' => 'owner/repo', 'permissions' => permissions }.compact), '', true]
  end

  def access_line(report) = report.lines.find { it.include?('Repository access') }.to_s

  def origin_identity = Shaka::GitOrigin.from(root: File.expand_path('..', __dir__)).fetch(:identity)
end
