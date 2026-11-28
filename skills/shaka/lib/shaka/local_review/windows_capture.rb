# frozen_string_literal: true

require_relative '../evidence/windows_check'

module Shaka
  # Captures a reviewer on Windows, where Ruby refuses `pgroup` (see
  # Doctor::BoundedCommand.process_groups?). Evidence::WindowsCheck starts it, holds it in a job, and
  # stops it without naming a process that may not be the reviewer any more. An interrupt or error
  # stops it too, once, and nothing waits on a leader that outlived its stop.
  class LocalReviewWindowsCapture
    def self.call(command, input, chdir, timeout) = new.call(command, input, chdir, timeout)

    def call(command, input, chdir, timeout)
      # Assigned inside the mask, so an interrupt pending at its end still finds the check to stop.
      Thread.handle_interrupt(Object => :never) { @check = Evidence::WindowsCheck.new(command, root: chdir, input: true) }
      streams = [@check.input, @check.output, @check.error]
      LocalReviewProcess.capture_streams(streams, @check.waiter, input, timeout, -> { stop }).tap { @finished = true }
    ensure
      begin
        stop if @check && !@finished
      ensure
        @check&.close(finished: @finished == true)
      end
    end

    private

    # Runs once: a second stop would find the job already closed and misreport it.
    def stop
      Thread.handle_interrupt(Object => :never) do
        next if @stopped

        @stopped = true
        limitation = @check.stop
        warn "shaka: #{limitation}" if limitation
      end
    end
  end
end
