# frozen_string_literal: true

require_relative 'deferred_rendering_test'

# An unchanged comment is read back before its stored rendering is trusted.
class DeferredRenderingReadbackTest < Minitest::Test
  include DeferredRenderingRunner

  def setup
    @calls = []
    @stored_html = '<p>Fine.</p>'
    @markdown = ['', DeferredRenderingTest::REFUSED, STATUS.new(1)]
    @comments = [{ 'id' => 9, 'body' => "#{mark}\nHello.", 'user' => { 'login' => 'agent' }, 'html_url' => URL }]
  end

  # Break caught: an edit after listing let newer HTML be checked against the listed body.
  def test_a_comment_edited_after_listing_is_not_checked_as_the_listed_one
    @stored_body = "#{mark}\nEdited."
    error = assert_raises(Shaka::Error) { publish(stored_check: ->(_) {}) }

    assert_includes error.message, 'changed after it was listed'
  end
end
