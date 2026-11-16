# frozen_string_literal: true

# Holds a process runner's deadline clock until its child creates a ready file, so a deadline test
# times the state the child set up, however long a loaded machine takes to start it. The hold ends
# after STARTUP seconds, so a child that never gets ready still meets its deadline.
module ReadyClock
  STARTUP = 30

  def self.hold(runner, ready)
    real = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    held = real.call
    ready_at = nil
    runner.define_singleton_method(:now) do
      ready_at ||= real.call if File.exist?(ready) || real.call - held > STARTUP
      ready_at ? held + real.call - ready_at : held
    end
  end
end
