# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/local_review/process'

class LocalReviewCleanupTest < Minitest::Test
  Waiter = Struct.new(:finished) do
    def pid = 123
    def join(seconds = nil) = seconds == 1 || !finished ? nil : self
  end

  def test_lasting_denied_kill_after_parent_exit_preserves_timeout_and_retries_kill
    with_denied_kill(true) do |waiter, attempts|
      error = assert_raises(Shaka::Error) { Shaka::LocalReviewProcess.wait_or_terminate(waiter, [], 1) }
      assert_includes error.message, 'timed out after 1s'
      assert_includes error.message, 'cleanup denied'
      assert_equal ['TERM', -123], attempts.first
      assert_operator attempts.count(['KILL', -123]), :>, 1
    end
  end

  # The race from #814: the group's last member is exiting, so KILL is denied until it is reaped.
  def test_kill_denied_while_group_exits_then_gone_finishes_cleanup
    with_denied_kill(true, denials: 2) do |waiter, attempts|
      assert_nil Shaka::LocalReviewProcess.wait_or_terminate(waiter, [], 1)
      assert_equal [['TERM', -123]] + ([['KILL', -123]] * 3), attempts
    end
  end

  def test_denied_kill_of_a_live_parent_is_not_hidden
    with_denied_kill(false) do |waiter, _attempts|
      assert_raises(Errno::EPERM) { Shaka::LocalReviewProcess.wait_or_terminate(waiter, [], 1) }
    end
  end

  private

  # Denies KILL `denials` times, then reports the group gone; nil denies every attempt.
  def with_denied_kill(finished, denials: nil)
    original = Process.method(:kill)
    attempts = []
    Process.define_singleton_method(:kill) do |signal, pid|
      attempts << [signal, pid]
      next unless signal == 'KILL'

      raise(denials.nil? || attempts.count(['KILL', pid]) <= denials ? Errno::EPERM : Errno::ESRCH)
    end
    yield Waiter.new(finished), attempts
  ensure
    Process.define_singleton_method(:kill, original)
  end
end
