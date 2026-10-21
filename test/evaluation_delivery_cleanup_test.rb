# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_snapshot'
require_relative 'support/evaluation_snapshot_fixture'

class EvaluationDeliveryCleanupTest < Minitest::Test
  include EvaluationSnapshotFixture

  def delayed_client(completed)
    client = Class.new(Shaka::Evaluation::DeliveryGitHub)
    client.define_method(:terminate) do |pid|
      sleep 3
      super(pid)
      completed << true
    end
    client.new(github: @gh, seconds: 2)
  end

  def test_expired_snapshot_budget_cannot_interrupt_process_cleanup
    File.write(File.join(@directory, 'responses'), JSON.generate([pull]))
    completed = []
    reader = Shaka::Evaluation::DeliverySnapshot.new(plan, github: @gh, seconds: 2)
    reader.instance_variable_set(:@api, delayed_client(completed))
    assert_raises(IOError) { reader.read }
    assert_equal [true], completed
  end
end
