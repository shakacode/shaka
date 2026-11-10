# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/evidence/tree_watch'

# Child processes the checks start, and the edit that races them.
module TreeWatchProcesses
  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # A loaded machine can take many seconds to start the check.
  def edit_when_started(pid_file, path)
    deadline = now + 60
    sleep 0.05 until File.size?(pid_file) || now > deadline
    File.write(path, "edit\n")
  end

  # A killed child stays visible until its new parent reaps it.
  def process_alive?(pid)
    deadline = now + 3
    loop do
      Process.kill(0, pid)
      return true if now > deadline

      sleep 0.1
    end
  rescue Errno::ESRCH
    false
  end

  def stop_escaped(pid_file)
    Process.kill('KILL', Integer(File.read(pid_file))) if File.size?(pid_file)
  rescue Errno::ESRCH
    nil
  end
end

# An edit made while a check runs voids its result, so the run stops soon after the edit
# instead of finishing first.
class EvidenceTreeWatchTest < Minitest::Test
  include EvidenceFixture
  include TreeWatchProcesses

  def setup
    @interval = Shaka::Evidence::TreeWatch.interval
    Shaka::Evidence::TreeWatch.interval = 0.2
  end

  def teardown
    Shaka::Evidence::TreeWatch.interval = @interval
  end

  def test_edit_during_run_stops_the_check_and_its_children
    with_checkout do |root, _ref|
      result, error, seconds, child = run_with_edit(root)

      assert_operator seconds, :<, 15
      assert_equal 'not_completed', result.fetch('status')
      assert_equal 'worktree changed mid-run', result.fetch('stop_reason')
      assert result.fetch('inputs_changed')
      assert_includes error, 'worktree changed mid-run'
      refute process_alive?(child), 'the check left a child running'
    end
  end

  def test_untouched_tree_lets_the_check_finish
    with_checkout do |root, _ref|
      write_check(root, "sleep 1\necho finished\n")
      result, error, = timed_run(root, expected_exit: 0)

      assert_equal 'completed', result.fetch('status')
      refute result.key?('stop_reason')
      assert_includes error, 'finished'
    end
  end

  def test_file_the_check_creates_and_removes_does_not_stop_it
    with_checkout do |root, _ref|
      command = ['sh', '-c', 'touch gone && rm gone && sleep 1']
      outcome = Shaka::Evidence::TreeWatch.new(command, root:, tree: tested(root)).run

      assert_predicate outcome.status, :success?
      assert_nil outcome.changed_tree
    end
  end

  # A descendant in its own session escapes the group signals and keeps the output pipe open.
  def test_stop_returns_while_an_escaped_descendant_holds_the_output
    with_checkout do |root, _ref|
      Dir.mktmpdir('shaka-tree-watch-') do |directory|
        pid_file = File.join(directory, 'escaped')
        outcome, seconds = run_escaped(root, pid_file)

        assert_operator seconds, :<, 20
        assert_predicate outcome, :stopped?
      ensure
        stop_escaped(pid_file)
      end
    end
  end

  private

  # The check is committed so the edit under test is the only change to the candidate tree.
  def write_check(root, body)
    path = File.join(root, '.agents/shaka/bin/test')
    File.write(path, "#!/bin/sh\n#{body}")
    File.chmod(0o755, path)
    git(root, 'add', '-A')
    commit(root)
  end

  # The check starts a child that outlives it unless the whole group is stopped.
  def run_with_edit(root)
    Dir.mktmpdir('shaka-tree-watch-') do |directory|
      pid_file = File.join(directory, 'child')
      write_check(root, "sleep 30 &\necho $! > '#{pid_file}'\nwait\n")
      editor = Thread.new { edit_when_started(pid_file, File.join(root, 'edited.txt')) }
      result, error, seconds = timed_run(root)
      editor.join
      [result, error, seconds, Integer(File.read(pid_file))]
    end
  end

  def timed_run(root, expected_exit: 1)
    head = git(root, 'rev-parse', 'HEAD')
    started = now
    output, error = capture_io do
      assert_equal expected_exit, Shaka::Evidence::Command.run(
        ['run', '--root', root, '--ref', head, '--repository', 'shakacode/shaka',
         '--command', 'test']
      )
    end
    [JSON.parse(output), error, now - started]
  end

  def tested(root) = Shaka::Evidence::CandidateTree.capture(root:)

  def run_escaped(root, pid_file)
    escaped = %(#{RbConfig.ruby} -e 'Process.setsid; File.write(ARGV[0], Process.pid.to_s); sleep 30' '#{pid_file}')
    watch = Shaka::Evidence::TreeWatch.new(['sh', '-c', "#{escaped} &\nsleep 30"], root:, tree: tested(root))
    editor = Thread.new { edit_when_started(pid_file, File.join(root, 'edited.txt')) }
    started = now
    outcome = nil
    capture_io { outcome = watch.run }
    editor.join
    [outcome, now - started]
  end
end
