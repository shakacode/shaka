# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/local_review/process'

class LocalReviewCleanupTest < Minitest::Test
  Waiter = Struct.new(:finished) do
    def pid = 123
    def join(seconds) = seconds == 1 || !finished ? nil : self
  end

  def test_denied_kill_after_parent_exit_preserves_timeout_and_both_signal_attempts
    with_denied_kill(true) do |waiter, attempts|
      error = assert_raises(Shaka::Error) { Shaka::LocalReviewProcess.wait_or_terminate(waiter, [], 1) }
      assert_includes error.message, 'timed out after 1s'
      assert_includes error.message, 'cleanup denied'
      assert_equal [['TERM', -123], ['KILL', -123]], attempts
    end
  end

  def test_denied_kill_of_a_live_parent_is_not_hidden
    with_denied_kill(false) do |waiter, _attempts|
      assert_raises(Errno::EPERM) { Shaka::LocalReviewProcess.wait_or_terminate(waiter, [], 1) }
    end
  end

  private

  def with_denied_kill(finished)
    original = Process.method(:kill)
    attempts = []
    Process.define_singleton_method(:kill) do |signal, pid|
      attempts << [signal, pid]
      raise Errno::EPERM if signal == 'KILL'
    end
    yield Waiter.new(finished), attempts
  ensure
    Process.define_singleton_method(:kill, original)
  end
end
