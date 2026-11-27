# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# How `--pr OWNER/REPO#NUMBER` is looked up and bound to this branch, and push settings that pause the check.
class BranchHeadPrTest < Minitest::Test
  include BranchHeadFixture

  PR_URL = 'https://push.example.com/base/repo/pull/7'

  # Answers only the gh lookup, so no network is used; every git command still runs for real.
  class FakeGh
    attr_reader :calls

    def initialize(answer, real_new)
      @answer = answer
      @real_new = real_new
      @calls = []
    end

    def with(options)
      @options = options
      self
    end

    def call(argv, chdir = nil)
      return @real_new.call(**@options).call(argv, chdir) unless argv.first == 'gh'

      @calls << argv
      [@answer, '', true]
    end
  end

  def setup
    super
    git(@task, 'remote', 'set-url', '--push', 'origin', 'https://push.example.com/base/repo.git')
  end

  def test_pr_lookup_names_the_origin_push_host_and_repository
    git(@task, 'remote', 'set-url', 'origin', 'https://fetch.example.com/base/repo.git')
    git(@task, 'remote', 'set-url', '--push', 'origin', 'https://push.example.com/base/repo.git')
    _status, _out, gh = run_branch('check', pull('MERGED', BRANCH))

    assert_equal(%w[--repo push.example.com/base/repo], gh.calls.first.each_cons(2).find { |flag, _| flag == '--repo' })
  end

  # An inherited GIT_DIR must not move the lookup to another repository's host.
  def test_pr_lookup_ignores_an_inherited_git_dir
    other = File.join(@dir, 'other')
    git(@dir, 'init', '--quiet', other)
    git(other, 'remote', 'add', 'origin', 'https://elsewhere.example.com/x/y.git')
    _status, _out, gh = with_env('GIT_DIR' => File.join(other, '.git')) { run_branch('check', pull('MERGED', BRANCH)) }

    assert_includes gh.calls.first, 'push.example.com/base/repo'
  end

  # Once a PR merges or closes, branch commands refuse instead of reporting a safe state for any branch.
  def test_finished_pr_refuses_the_check
    [pull('MERGED', BRANCH), pull('CLOSED', 'someone-else')].each do |answer|
      status, = run_branch('check', answer)

      assert_equal 1, status
    end
  end

  def test_open_pr_in_another_repository_pauses_the_check
    answer = pull('OPEN', BRANCH).merge('headRepository' => { 'name' => 'fork' },
                                        'headRepositoryOwner' => { 'login' => 'someone' })
    status, out, = run_branch('check', answer)

    assert_equal [2, 'unreadable'], [status, JSON.parse(out)['state']]
  end

  # GitHub Enterprise over SSH: the PR's https URL names the same host and repository as the SSH origin.
  def test_ssh_origin_matches_the_pr_https_url
    git(@task, 'remote', 'set-url', '--push', 'origin', 'git@git.example.com:acme/repo.git')
    pr_head = { 'url' => 'https://git.example.com/acme/repo', 'branch' => BRANCH }
    destination = Shaka::BranchHead::Destination.new(root: @task, branch: BRANCH, pr_head:)

    assert_equal 'git@git.example.com:acme/repo.git', destination.url
  end

  def test_empty_last_push_default_still_overrides_origin
    git(@task, 'remote', 'set-url', '--push', 'origin', @origin)
    git(@task, 'config', '--add', 'remote.pushDefault', 'origin')
    git(@task, 'config', '--add', 'remote.pushDefault', '')

    assert_includes check['error'], 'origin only'
  end

  # A plain push follows a named upstream remote, so tracking a fork's branch would send the push there.
  def test_upstream_on_another_remote_pauses_the_check
    git(@task, 'remote', 'set-url', '--push', 'origin', @origin)
    git(@task, 'remote', 'add', 'fork', bare_copy('fork.git'))
    git(@task, 'config', "branch.#{BRANCH}.remote", 'fork')

    assert_includes check['error'], 'tracks fork'
  end

  # A mirror remote refuses a single-branch push, so the check pauses before any edit.
  def test_mirror_remote_pauses_the_check
    git(@task, 'remote', 'set-url', '--push', 'origin', @origin)
    git(@task, 'config', 'remote.origin.mirror', 'true')

    assert_includes check['error'], 'mirror'
  end

  private

  def pull(state, branch)
    { 'url' => PR_URL, 'state' => state, 'headRefName' => branch,
      'headRepository' => { 'name' => 'repo' }, 'headRepositoryOwner' => { 'login' => 'base' } }
  end

  def run_branch(operation, answer)
    gh = nil
    status = nil
    out, = capture_io do
      with_fake_gh(JSON.generate(answer)) do |fake|
        gh = fake
        status = Shaka::BranchHead::Command.run([operation, '--root', @task, '--pr', 'base/repo#7'])
      end
    end
    [status, out, gh]
  end

  def with_fake_gh(answer)
    original = Shaka::Doctor::BoundedCommand.method(:new)
    fake = FakeGh.new(answer, original)
    Shaka::Doctor::BoundedCommand.define_singleton_method(:new) { |**options| fake.with(options) }
    yield fake
  ensure
    Shaka::Doctor::BoundedCommand.define_singleton_method(:new, original)
  end

  def with_env(values)
    saved = values.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end
