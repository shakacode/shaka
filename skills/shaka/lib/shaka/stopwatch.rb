# frozen_string_literal: true

module Shaka
  # Times a step on a clock that cannot jump backward. Where the platform also has a clock that stops
  # while the machine sleeps, the result adds `awake_ms`, so a run inflated by sleep can be told from
  # a slow one.
  module Stopwatch
    AWAKE_CLOCK = (Process::CLOCK_UPTIME_RAW if defined?(Process::CLOCK_UPTIME_RAW))

    module_function

    def start = [clock, awake]

    def elapsed(started)
      wall, awake_start = started
      duration = milliseconds(clock - wall)
      awake_now = awake
      record = { 'duration_ms' => duration }
      # The two clocks are read a moment apart, so awake time can round a millisecond past wall time.
      record['awake_ms'] = [milliseconds(awake_now - awake_start), duration].min if awake_now && awake_start
      record
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    def awake = (Process.clock_gettime(AWAKE_CLOCK) if AWAKE_CLOCK)
    def milliseconds(seconds) = (seconds * 1000).round
  end
end
