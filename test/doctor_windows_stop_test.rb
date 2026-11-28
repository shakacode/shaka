# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/doctor/bounded_command'

# Doctor's Windows stop names the leader by pid only while Ruby has not reaped it, and only when no
# job ended the tree; a reaped leader's pid may already belong to an unrelated process.
class DoctorWindowsStopTest < Minitest::Test
  Leader = Struct.new(:pid, :alive) do
    def alive? = alive
  end
  Job = Struct.new(:ended) do
    def terminate = ended
  end

  def test_taskkill_runs_only_for_a_live_leader_no_job_ended
    assert_equal [42], taskkills(job: nil, alive: true)
    assert_equal [42], taskkills(job: Job.new(false), alive: true)
    assert_empty taskkills(job: Job.new(true), alive: true)
    assert_empty taskkills(job: nil, alive: false)
    assert_empty taskkills(job: Job.new(false), alive: false)
  end

  private

  def taskkills(job:, alive:)
    killed = []
    command = Shaka::Doctor::BoundedCommand.new(timeout: 1)
    command.define_singleton_method(:kill_tree) { |pid| killed << pid }
    child = Shaka::Doctor::BoundedCommand::Child.new(Leader.new(42, alive), nil, nil, false, job)
    on_windows { command.send(:terminate, child) }
    killed
  end

  def on_windows
    original = Shaka::Doctor::BoundedCommand.method(:process_groups?)
    Shaka::Doctor::BoundedCommand.define_singleton_method(:process_groups?) { false }
    yield
  ensure
    Shaka::Doctor::BoundedCommand.define_singleton_method(:process_groups?, original)
  end
end
