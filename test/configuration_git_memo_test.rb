# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/configuration'
require 'fileutils'
require 'open3'
require 'tmpdir'

class ConfigurationGitMemoTest < Minitest::Test
  MEMO = Shaka::Configuration::GitMemo
  SHA = 'a' * 40
  Status = Struct.new(:success?)

  def setup = MEMO.enable
  def teardown = MEMO.disable

  def test_disabled_memo_runs_every_lookup
    MEMO.disable
    calls = 0
    2.times { MEMO.fetch(:key) { calls += 1 } }

    assert_equal 2, calls
  end

  def test_commit_lookup_by_branch_name_runs_every_time
    calls = 0
    2.times { MEMO.commit([:commit, 'main'], 'main') { calls += 1 } }
    2.times { MEMO.commit([:commit, SHA], SHA) { calls += 1 } }

    assert_equal 3, calls
  end

  def test_failed_lookup_is_tried_again
    calls = 0
    2.times do
      assert_raises(Shaka::Error) { MEMO.fetch(:key) { (calls += 1) && raise(Shaka::Error, 'git failed') } }
    end
    results = [false, true, true].map do |success|
      MEMO.capture(:capture, SHA) { (calls += 1) && ['', '', Status.new(success)] }
    end

    assert_equal 4, calls
    assert_equal([false, true, true], results.map { |result| result.last.success? })
  end

  def test_missing_layout_is_read_again_after_the_commit_arrives
    Dir.mktmpdir do |directory|
      source, root = %w[source root].map { |name| File.join(directory, name) }
      sha = commit_contract(source)
      FileUtils.mkdir_p(root)
      git(root, 'init', '--quiet')
      assert_nil Shaka::Configuration::Layout.commit(root:, sha:, allow_missing: true)

      git(root, 'fetch', '--quiet', source, sha)
      assert_equal Shaka::Configuration::Layout::CURRENT,
                   Shaka::Configuration::Layout.commit(root:, sha:, allow_missing: true)
    end
  end

  def test_layout_with_a_bounded_runner_reads_git_every_time
    calls = 0
    runner = lambda do |*|
      calls += 1
      ['', '', Status.new(false)]
    end
    2.times { Shaka::Configuration::Layout.commit(root: '/repo', sha: SHA, allow_missing: true, git: runner) }

    assert_equal 2, calls
  end

  private

  def commit_contract(source)
    FileUtils.mkdir_p(File.join(source, '.agents/shaka'))
    File.write(File.join(source, '.agents/shaka/config.yml'), "version: 1\n")
    git(source, 'init', '--quiet')
    git(source, 'add', '.')
    git(source, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--quiet', '-m', 'contract')
    git(source, 'rev-parse', 'HEAD').strip
  end

  def git(root, *)
    output, error, status = Open3.capture3('git', '-C', root, *)
    raise error unless status.success?

    output
  end
end
