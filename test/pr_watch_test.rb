# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/pr_watch'
require 'shaka/pr_watch/command'
require 'open3'

class PrWatchTest < Minitest::Test
  HEAD = 'a' * 40
  MOVED = 'b' * 40

  class FakeGitHub
    attr_reader :reads

    def initialize(frames)
      @frames = frames
      @reads = 0
    end

    def snapshot
      @reads += 1
      frame.fetch(:pr)
    end

    def required_checks
      raise Shaka::Error, 'checks unavailable' if frame.fetch(:required) == :unavailable

      frame.fetch(:required)
    end

    def configured_required_checks = []
    def checks = frame.fetch(:checks)
    def advance = @index = [(@index || 0) + 1, @frames.length - 1].min

    private

    def frame = @frames.fetch(@index || 0)
  end

  def test_wakes_when_required_and_review_checks_finish
    frames = [frame(required: [check('validate', 'PENDING', 'pending')],
                    checks: [check('claude-review', 'PENDING', 'pending')]),
              frame(required: [check('validate', 'SUCCESS', 'pass')],
                    checks: [check('claude-review', 'SUCCESS', 'pass')])]

    assert_equal 'checks_terminal', watch(frames)
  end

  def test_missing_review_job_waits_until_timeout
    frames = [frame(required: [check('validate', 'SUCCESS', 'pass')], checks: [])]

    assert_equal 'timeout', watch(frames, timeout: 2)
  end

  def test_no_configured_checks_waits_for_a_real_wake
    github = FakeGitHub.new([frame(required: [], checks: [])])
    now = 0
    adapters = { clock: -> { now }, sleeper: ->(seconds) { now += seconds },
                 comments: -> { comments_packet(frame) } }
    watcher = Shaka::PrWatch.new(github, head: HEAD, ci_jobs: [],
                                         settings: { interval: 1, settle: 1, timeout: 2 }, adapters:)

    assert_equal 'timeout', watcher.call
  end

  def test_failed_checks_are_terminal_and_wake_the_agent
    frames = [frame(required: [check('validate', 'FAILURE', 'fail')],
                    checks: [check('claude-review', 'FAILURE', 'fail')])]

    assert_equal 'checks_terminal', watch(frames)
  end

  def test_unavailable_required_checks_fail_instead_of_waiting
    error = assert_raises(Shaka::Error) { watch([frame(required: :unavailable)]) }

    assert_includes error.message, 'checks unavailable'
  end

  def test_head_move_wakes_before_check_completion
    frames = [frame, frame(head: MOVED)]

    assert_equal 'head_moved', watch(frames)
  end

  def test_new_trusted_comment_wakes_after_settle_window
    frames = [frame(comments: [1]), frame(comments: [1, 2]), frame(comments: [1, 2])]

    assert_equal 'trusted_comment', watch(frames)
  end

  def test_settle_window_wakes_before_the_next_regular_poll
    github = FakeGitHub.new([frame(required: [check('validate', 'SUCCESS', 'pass')])])
    now = 0
    adapters = { clock: -> { now }, sleeper: ->(seconds) { now += seconds },
                 comments: -> { comments_packet(frame) } }
    watcher = Shaka::PrWatch.new(github, head: HEAD, ci_jobs: [],
                                         settings: { interval: 60, settle: 15, timeout: 120 }, adapters:)

    assert_equal 'checks_terminal', watcher.call
    assert_equal 15, now
  end

  def test_saved_baseline_catches_a_comment_that_arrived_before_startup
    baseline = comments_packet(frame(comments: [1]))

    assert_equal 'trusted_comment', watch([frame(comments: [1, 2])], baseline:)
  end

  def test_timeout_preserves_a_known_comment_reason
    frames = [frame(comments: [1]), frame(comments: [1, 2])]

    assert_equal 'trusted_comment', watch(frames, timeout: 1)
  end

  def test_untrusted_comment_does_not_wake
    frames = [frame(comments: [1]), frame(comments: [1], excluded: [3])]

    assert_equal 'timeout', watch(frames, timeout: 2)
  end

  def test_closed_pr_wakes
    frames = [frame, frame(state: 'MERGED')]

    assert_equal 'closed', watch(frames)
  end

  def test_cli_refuses_a_watch_without_a_trusted_ref
    command = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
    output, error, status = Open3.capture3(command, 'pr', 'watch', 'owner/repo', '42', '--head', HEAD)

    assert_equal '', error
    assert_equal "SHAKA_WAKE error: Expected OWNER/REPO NUMBER and --head SHA --ref SHA.\n", output
    refute_predicate status, :success?
  end

  private

  def check(name, state, bucket) = { 'name' => name, 'state' => state, 'bucket' => bucket }

  def frame(**values)
    defaults = { head: HEAD, state: 'OPEN', required: [check('validate', 'PENDING', 'pending')],
                 checks: [], comments: [], excluded: [] }
    current = defaults.merge(values)
    { pr: { 'headRefOid' => current[:head], 'state' => current[:state] }, required: current[:required],
      checks: current[:checks], comments: current[:comments], excluded: current[:excluded] }
  end

  def watch(frames, timeout: 10, baseline: nil)
    github = FakeGitHub.new(frames)
    now = 0
    reader = -> { comments_packet(frames.fetch([now, frames.length - 1].min)) }
    tick = lambda do |seconds|
      now += seconds
      github.advance
    end
    settings = { interval: 1, timeout: timeout, settle: 1, baseline: }
    adapters = { clock: -> { now }, sleeper: tick, comments: reader }
    Shaka::PrWatch.new(github, head: HEAD, ci_jobs: ['claude-review'], settings:, adapters:).call
  end

  def comments_packet(frame)
    { 'issue_comments' => frame[:comments].map { |id| { 'id' => id } },
      'review_summaries' => [], 'inline_comments' => [],
      'excluded_interactions' => frame[:excluded].map { |id| { 'id' => id } } }
  end
end

class PrWatchBaselineTest < Minitest::Test
  def test_accepts_a_saved_comments_packet_for_the_expected_head
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'comments.json')
      File.write(path, JSON.generate('head' => 'a' * 40, 'issue_comments' => [],
                                     'review_summaries' => [], 'inline_comments' => []))

      assert_equal 'a' * 40, Shaka::PrWatch::Command.baseline(baseline: path, head: 'a' * 40)['head']
    end
  end

  def test_refuses_a_saved_comment_read_from_another_head
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'comments.json')
      File.write(path, JSON.generate('head' => 'b' * 40))

      error = assert_raises(Shaka::Error) do
        Shaka::PrWatch::Command.baseline(baseline: path, head: 'a' * 40)
      end
      assert_includes error.message, 'expected PR head'
    end
  end
end
