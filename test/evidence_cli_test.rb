# frozen_string_literal: true

require_relative 'evidence_fixture'

class EvidenceCliTest < Minitest::Test
  include EvidenceFixture

  def test_help_exits_successfully
    evidence_output, = capture_io { assert_equal 0, Shaka::Evidence::Command.run(%w[run --help]) }
    review_output, = capture_io { assert_equal 0, Shaka::LocalReview.run(%w[check --help]) }
    assert_includes evidence_output, 'Usage: shaka evidence run'
    assert_includes review_output, 'Usage: shaka review check'
  end

  def test_bind_rejects_result_inside_candidate_checkout
    with_checkout do |root, ref|
      path = File.join(root, 'result.json')
      File.write(path, JSON.generate(run_check(root, ref)))
      error = assert_raises(Shaka::Error) { Shaka::Evidence::Result.local_file!(root, path) }
      assert_includes error.message, 'inside candidate checkout'
    end
  end
end
