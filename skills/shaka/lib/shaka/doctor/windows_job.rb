# frozen_string_literal: true

require 'fiddle'
require 'fiddle/import'

module Shaka
  class Doctor
    # Names a Windows process and the descendants created after it joins.
    # taskkill /PID loses them once the leader has exited and been reaped.
    class WindowsJob
      # kernel32 job-object calls. Loaded only on Windows.
      module API
        extend Fiddle::Importer

        dlload 'kernel32.dll'
        extern 'void* CreateJobObjectW(void*, void*)'
        extern 'void* OpenProcess(unsigned long, int, unsigned long)'
        extern 'int AssignProcessToJobObject(void*, void*)'
        extern 'int TerminateJobObject(void*, unsigned int)'
        extern 'int CloseHandle(void*)'
      end

      # PROCESS_TERMINATE | PROCESS_SET_QUOTA, then PROCESS_ALL_ACCESS.
      # AssignProcessToJobObject requires the first pair. A runner that already
      # holds the process in a job can deny that pair and still allow the second.
      PROCESS_RIGHTS = [0x0101, 0x1F0FFF].freeze

      def self.adopt(pid)
        job = new
        return job.close unless job.handle

        job.place(pid) || job.close
      end

      def initialize
        @handle = API.CreateJobObjectW(nil, nil)
        @handle = nil if missing?(@handle)
      end

      attr_reader :handle

      def place(pid)
        PROCESS_RIGHTS.each { |rights| return self if place_with(pid, rights) }
        nil
      end

      def terminate
        API.TerminateJobObject(@handle, 1) if @handle
        close
      end

      def close
        API.CloseHandle(@handle) if @handle
        @handle = nil
      end

      private

      def place_with(pid, rights)
        process = API.OpenProcess(rights, 0, pid)
        return false if missing?(process)

        assigned = API.AssignProcessToJobObject(@handle, process) != 0
        API.CloseHandle(process)
        assigned
      end

      def missing?(handle) = handle.nil? || handle.to_i.zero?
    end
  end
end
