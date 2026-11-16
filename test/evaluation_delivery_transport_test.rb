# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_readback'
require_relative 'support/evaluation_delivery_fixture'

class EvaluationDeliveryTransportTest < Minitest::Test
  include EvaluationDeliveryFixture

  def test_failed_or_deleted_review_is_not_unchanged_and_does_not_expose_stderr
    receipt = capture
    File.write(@response, 'failure')
    refute reader.unchanged?(receipt)
    error = assert_raises(IOError) { capture }
    refute_includes error.message, 'private-error'
  end

  def test_malformed_or_partial_json_is_not_a_receipt
    ['not-json', "\xff".b, JSON.generate({ data: { node: review }, errors: [{ message: 'partial' }] })].each do |bytes|
      File.binwrite(@response, bytes)
      assert_raises(IOError) { capture }
    end
  end

  def test_oversized_api_response_is_refused
    File.write(@response, 'x' * 1_048_577)
    assert_raises(IOError) { capture }
  end

  def test_deadline_terminates_and_reaps_the_native_child
    File.write(@gh, "#!/bin/sh\nexec sleep 60\n")
    pids = spawned_by_open3 do
      transport = reader(seconds: 2)
      assert_raises(IOError) { transport.read(node_id: NODE, review_id: 5_566_107_686, actor: 'fixture-agent') }
    end
    assert_equal 1, pids.size
    assert_raises(Errno::ESRCH) { Process.kill(0, pids.first) }
  end

  private

  # The pids Open3 spawns, so the test needs no report from a child the deadline may stop before it runs.
  def spawned_by_open3
    pids = []
    Open3.define_singleton_method(:spawn) { |*arguments| Process.spawn(*arguments).tap { pids << it } }
    yield
    pids
  ensure
    Open3.singleton_class.remove_method(:spawn)
  end
end
