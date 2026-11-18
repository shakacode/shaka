# frozen_string_literal: true

require_relative '../executable_file'

module Shaka
  # Ends a Windows process and its descendants. Windows has no process groups, so a job object
  # holds the leader and the descendants it starts once it joins.
  module LocalReviewWindowsTree
    singleton_class.attr_accessor :stop_seconds
    # Seconds a stopped tree gets to exit before its leader is terminated directly. Tests shorten it.
    self.stop_seconds = 10

    # Without a job, as when a later Ruby cannot load fiddle under --disable-gems or kernel32
    # refuses a call, taskkill alone stops it. An error here would leave popen3 waiting on the child.
    def self.adopt(pid)
      return unless ExecutableFile.windows?

      require_relative '../doctor/windows_job'
      Doctor::WindowsJob.adopt(pid) || warn_without_job('the job refused the process')
    rescue LoadError, StandardError => e
      warn_without_job(e.class.name)
    end

    def self.warn_without_job(reason)
      warn "shaka: no Windows job holds the process (#{reason}); taskkill will stop it, " \
           'which misses descendants whose leader has exited'
    end

    # The job ends the tree, even descendants whose leader already exited. Without a job, taskkill
    # /T ends the leader's live descendants, running beside the wait so a stalled taskkill cannot
    # hold it. A leader that outlasts both is terminated directly, so the wait for its status always
    # ends. Only a live leader still owns its pid: once reaped, the pid may name an unrelated
    # process, so nothing is sent to it.
    def self.end_tree(waiter, job, seconds: stop_seconds)
      job ? job.terminate : (start_taskkill(waiter.pid) if waiter.alive?)
      Process.kill('KILL', waiter.pid) unless waiter.join(seconds)
      waiter.join
    rescue Errno::ESRCH
      waiter.join
    end

    def self.start_taskkill(pid)
      Process.detach(spawn(taskkill, '/F', '/T', '/PID', pid.to_s, out: File::NULL, err: File::NULL))
    rescue SystemCallError
      nil
    end

    # By full path: a bare name would let Windows find a taskkill.exe in the current directory,
    # which can be the candidate checkout.
    def self.taskkill = File.join(ENV.fetch('SystemRoot', 'C:/Windows'), 'System32', 'taskkill.exe')
  end
end
