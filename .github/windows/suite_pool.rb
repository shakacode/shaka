# frozen_string_literal: true

require 'tempfile'

# Runs each suite file in its own process. One file that cannot load, or that
# does not exit, is recorded and the rest still run.
class WindowsSuitePool
  def initialize(session, workers:, seconds:)
    @session = session
    @workers = workers
    @seconds = seconds
    @ok = true
    @stop = false
    @queue = []
    @active = []
  end

  def run(files)
    @queue = files.map.with_index(1) { |file, index| { file:, index:, total: files.size } }
    pump until @queue.empty? && @active.empty?
    @ok
  end

  private

  def pump
    start_next while room?
    ready = @active.reject { |run| busy?(run) }
    ready.each { |run| finish(run) }
    @active -= ready
    sleep 0.2 if @active.any?
  end

  def room? = !@stop && @active.size < @workers && @queue.any?

  def start_next
    item = @queue.shift
    puts "suite #{item[:index]}/#{item[:total]} #{item[:file]}"
    log = Tempfile.new('shaka-suite')
    pid = spawn_file(item[:file], log)
    @active << { file: item[:file], pid:, log:, deadline: clock + @seconds }
  rescue SystemCallError => e
    @ok = false
    puts "FAIL #{item[:file]}: #{e.class}: #{e.message}"
  end

  def spawn_file(file, log)
    Process.spawn(@session.suite_child_env, *@session.suite_file_command(file),
                  chdir: @session.root, out: log.path, err: %i[child out])
  end

  def busy?(run)
    finished = Process.wait2(run[:pid], Process::WNOHANG)
    if finished
      run[:status] = finished.last
      return false
    end
    return true if clock < run[:deadline]

    expire(run)
    false
  end

  def expire(run)
    run[:expired] = true
    @session.stop(run[:pid])
    run[:status] = wait_briefly(run[:pid], clock + 5)&.last
  end

  def wait_briefly(pid, grace)
    found = nil
    while found.nil? && clock < grace
      found = Process.wait2(pid, Process::WNOHANG)
      sleep 0.1 if found.nil? && clock < grace
    end
    found
  end

  def finish(run)
    output = File.read(run[:log].path)
    run[:log].close!
    classify(run, output)
  end

  def classify(run, output)
    return gap(run[:file], "still running after #{@seconds}s", output) if run[:expired]
    return puts("PASS #{run[:file]}") if run[:status]&.success?
    return stop_for_git(output) if output.include?('git executable not found')

    gap_failure(run[:file], output)
  end

  def stop_for_git(output)
    puts output
    @stop = true
    @queue.clear
    gap('test/test_helper.rb', 'git executable not found; pull request 748 looks up git.exe', nil)
  end

  def gap_failure(file, output)
    puts output
    @ok = false
    puts "FAIL #{file}"
  end

  def gap(file, reason, output)
    puts output if output
    @ok = false
    puts "WINDOWS suite gap: #{file} - #{reason}"
  end

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
