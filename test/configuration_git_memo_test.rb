# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/configuration'

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

  def test_layout_with_a_bounded_runner_reads_git_every_time
    calls = 0
    runner = lambda do |*|
      calls += 1
      ['', '', Status.new(false)]
    end
    2.times { Shaka::Configuration::Layout.commit(root: '/repo', sha: SHA, allow_missing: true, git: runner) }

    assert_equal 4, calls
  end
end
