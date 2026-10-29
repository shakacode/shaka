# frozen_string_literal: true

# Expires every evaluation deadline once the test's readiness check passes, so a slow child
# start on a loaded machine cannot reach the deadline first. Deadlines read the monotonic clock;
# this moves it an hour ahead from that point on. Timeout keeps the real clock.
module EvaluationDeadlineClock
  def expire_deadlines_when(ready)
    real = Process.method(:clock_gettime)
    expired = false
    Process.define_singleton_method(:clock_gettime) do |id, *rest|
      monotonic = id == Process::CLOCK_MONOTONIC && rest.empty?
      expired ||= monotonic && ready.call
      real.call(id, *rest) + (monotonic && expired ? 3600 : 0)
    end
    yield
  ensure
    Process.define_singleton_method(:clock_gettime, real) if real
  end
end
