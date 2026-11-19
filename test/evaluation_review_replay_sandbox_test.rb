# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/review_replay_sandbox'

class EvaluationReviewReplaySandboxTest < Minitest::Test
  Sandbox = Shaka::Evaluation::ReviewReplaySandbox

  def test_launcher_replaces_the_read_only_default_with_fixture_permissions
    Dir.mktmpdir do |fixture|
      arguments = Sandbox.exec_arguments(fixture, %w[exec -s read-only --ignore-user-config --json -])
      filesystem = %({":minimal"="read",#{File.realpath(fixture).to_json}="read"})

      assert_equal %w[-a never exec], arguments.first(3)
      assert_includes arguments, %(default_permissions="shaka-review-replay")
      assert_includes arguments, %(permissions.shaka-review-replay.network.enabled=false)
      assert_includes arguments, "permissions.shaka-review-replay.filesystem=#{filesystem}"
      assert_equal %w[--ignore-user-config --json -], arguments.last(3)
    end
  end

  def test_launcher_refuses_unrecognized_helper_shape
    assert_raises(ArgumentError) { Sandbox.exec_arguments(Dir.pwd, %w[exec -s workspace-write]) }
  end
end
