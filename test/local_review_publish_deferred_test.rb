# frozen_string_literal: true

require_relative 'local_review_commit_publish_test'

# `review publish` where GitHub refuses its Markdown renderer checks each stored part instead.
class LocalReviewPublishDeferredTest < Minitest::Test
  include LocalReviewCommentFixture

  # Refuses the renderer, then hands each stored part's rendering to the publisher's check.
  class Refusing < LocalReviewCommitPublishTest::Timeline
    attr_accessor :stored

    def verify_rendering(*, **) = raise(Shaka::DeferredRendering::Refused, 'refused')

    def reply(body:, stored_check:, **)
      stored_check.call(stored || markdown(body))
      super
    end
  end

  def test_each_part_is_checked_once_stored_and_the_mode_is_reported
    github = Refusing.new
    status, out, = publish(github, 'rounds' => [round])

    assert_equal 0, status
    assert_equal 1, github.replies.size
    assert_equal 'after_write', JSON.parse(out).fetch('rendering_check')
  end

  def test_a_stored_part_that_loses_its_layout_fails_the_publication
    github = Refusing.new
    github.stored = '<p>flattened</p>'
    status, _, err = publish(github, 'rounds' => [round])

    assert_equal 1, status
    assert_includes err, 'collapsed with the attestation last'
    assert_empty github.replies
  end

  private

  def publish(github, content)
    Tempfile.create(['content-', '.json']) do |file|
      file.write(JSON.generate(content))
      file.close
      status = nil
      out, err = capture_io do
        status = Shaka::LocalReview.run(['publish', 'o/r', '7', '--content-file', file.path], github:)
      end
      [status, out, err]
    end
  end
end
