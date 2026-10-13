# frozen_string_literal: true

require_relative 'github_publication_test'
require 'shaka/review_reply'

class ReplyContentTest < Minitest::Test
  include PublicationFixtures

  CONTENT = { 'identity' => { 'agent' => 'Codex', 'provider' => 'OpenAI', 'model' => 'terra', 'effort' => 'low' },
              'summary' => 'A summary.' }.freeze

  def test_unsupported_content_is_refused_before_any_github_request
    content = CONTENT.merge('sections' => [{ 'heading' => 'Explanation', 'body' => 'Do not drop this.' }],
                            'reviews' => ['https://github.com/owner/repo/pull/42#issuecomment-1'])
    github = client

    error = assert_raises(Shaka::Error) { publish(content, github) }

    assert_includes error.message, 'sections'
    assert_includes error.message, 'summary'
    assert_empty @calls
  end

  def test_each_unsupported_field_is_named_even_when_empty
    %w[sections details table head typo].each do |field|
      error = assert_raises(Shaka::Error) { publish(CONTENT.merge(field => nil), client) }

      assert_includes error.message, field
    end
  end

  def test_a_supported_reply_is_created_and_a_stable_key_retry_updates_it
    posted = "<!-- shaka:reply:fix-1 -->\n#{BODY}"
    updated = posted.sub('A summary.', 'Updated summary.')
    github = retry_client(posted, updated)

    assert_equal 9, publish(CONTENT, github)['id']
    assert_equal 9, publish(CONTENT.merge('summary' => 'Updated summary.'), github)['id']

    assert_equal ['POST', posted], [sent_method(4), sent_body(4)]
    assert_equal ['PATCH', updated], [sent_method(8), sent_body(8)]
  end

  private

  def retry_client(posted, updated)
    client(pull_response(''), viewer_response, response([]), html_response('<p>ok</p>'),
           response({ 'id' => 9, 'body' => posted }), pull_response(''),
           response([keyed(9, posted)]), html_response('<p>ok</p>'),
           response({ 'id' => 9, 'body' => updated }))
  end

  def publish(content, github)
    github.reply(body: Shaka::ReviewReply.compose(content, github), key: 'fix-1')
  end
end
