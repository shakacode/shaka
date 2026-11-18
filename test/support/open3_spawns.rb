# frozen_string_literal: true

require 'open3'

# Records the pids Open3 spawns while the block runs, so a deadline test needs no report from a child
# the deadline may stop before it runs.
module Open3Spawns
  def self.record
    pids = []
    Open3.define_singleton_method(:spawn) { |*arguments| Process.spawn(*arguments).tap { pids << it } }
    yield
    pids
  ensure
    Open3.singleton_class.remove_method(:spawn)
  end
end
