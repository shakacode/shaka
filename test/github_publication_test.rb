# frozen_string_literal: true

require_relative 'github_helper'

# Fixtures shared by the description and reply surfaces.
module PublicationFixtures
  include GitHubHelper

  BODY = "🤖 Codex · OpenAI · terra · low\n\nA summary.\n"
  MANAGED = "<!-- shaka:begin -->\n#{BODY}<!-- shaka:end -->".freeze

  def pull_response(body)
    response({ 'id' => 1, 'number' => 42, 'body' => body })
  end

  def html_response(html)
    [html, 'private stderr must not be disclosed', STATUS.new(0)]
  end

  def sent_body(index = 3) = JSON.parse(@calls[index].last)['body']

  def viewer_response(login = 'shaka-bot') = response({ 'login' => login })

  def full_page = Array.new(100) { |index| keyed(index + 100, 'filler') }

  def keyed(id, body, login = 'shaka-bot')
    { 'id' => id, 'body' => body, 'user' => { 'login' => login } }
  end

  def sent_method(index = 2)
    argv = @calls[index].first
    argv[argv.index('--method') + 1]
  end

  def call_text(index) = @calls[index].first.join(' ')
end

# A description must merge into the existing body and be confirmed once stored.
class GitHubDescriptionTest < Minitest::Test
  include PublicationFixtures

  def test_description_keeps_content_other_authors_appended
    existing = "old\n\n<!-- coderabbit -->\nSummary by CodeRabbit"
    github = client(pull_response(existing), html_response('<p>ok</p>'), pull_response(existing),
                    pull_response("#{MANAGED}\n\n#{existing}"))
    github.description(body: BODY)
    sent = sent_body
    assert_equal "#{MANAGED}\n\n#{existing}", sent
    assert_includes sent, 'Summary by CodeRabbit'
  end

  def test_republishing_replaces_only_the_managed_region
    existing = "#{MANAGED}\n\nSummary by CodeRabbit"
    updated = "<!-- shaka:begin -->\nNew text.\n<!-- shaka:end -->\n\nSummary by CodeRabbit"
    github = client(pull_response(existing), html_response('<p>ok</p>'), pull_response(existing),
                    pull_response(updated))
    github.description(body: "New text.\n")
    assert_equal updated, sent_body
    assert_equal 1, sent_body.scan('<!-- shaka:begin -->').size
  end

  def test_an_ambiguous_managed_region_is_refused_rather_than_truncating_the_body
    quoted = "Docs quoting <!-- shaka:begin --> in prose.\n\n#{MANAGED}\n\nkeep me"
    github = client(pull_response(quoted))
    error = assert_raises(Shaka::Error) { github.description(body: BODY) }
    assert_includes error.message, 'ambiguous'
    assert_equal 1, @calls.size
  end

  def test_an_edit_that_lands_while_the_update_is_prepared_is_not_erased
    github = client(pull_response('original'), html_response('<p>ok</p>'), pull_response('someone edited'))
    error = assert_raises(Shaka::Error) { github.description(body: BODY) }
    assert_includes error.message, 'changed while'
    assert_equal 3, @calls.size, 'the update must not be written after a concurrent edit'
  end

  def test_stored_body_that_does_not_match_the_submission_is_reported
    github = client(pull_response(''), html_response('<p>ok</p>'), pull_response(''), pull_response('something else'))
    assert_raises(Shaka::Error) { github.description(body: BODY) }
  end

  def test_a_table_that_github_does_not_render_is_reported
    table = "#{BODY}\n| A | B |\n| --- | --- |\n| 1 | 2 |\n"
    github = client(pull_response(''), html_response('<p>| A | B |</p>'))
    error = assert_raises(Shaka::Error) { github.description(body: table) }
    assert_includes error.message, 'table'
  end

  def test_a_rendered_table_passes_the_readback
    table = "#{BODY}\n| A | B |\n| --- | --- |\n| 1 | 2 |\n"
    managed = "<!-- shaka:begin -->\n#{table}<!-- shaka:end -->"
    github = client(pull_response(''), html_response('<table><tr><td>1</td></tr></table>'), pull_response(''),
                    pull_response(managed))
    assert_equal managed, github.description(body: table)['body']
  end

  def test_escape_sequences_surviving_into_the_rendered_output_are_reported
    github = client(pull_response(''), html_response('<p>A summary.\n\nMore.</p>'))
    error = assert_raises(Shaka::Error) { github.description(body: BODY) }
    assert_includes error.message, 'escape sequence'
  end
end

# A reply must find its own keyed comment and never touch anyone else's.
class GitHubReplyTest < Minitest::Test
  include PublicationFixtures

  def test_an_inline_reply_is_created_on_the_original_review_thread
    github = client(pull_response(''), viewer_response, response([]), html_response('<p>ok</p>'),
                    response({ 'id' => 9, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1', comment: 4_031_740_163)
    assert_equal ['POST', true, true, "<!-- shaka:reply:fix-1 -->\n#{BODY}"],
                 [sent_method(4), call_text(2).include?('pulls/42/comments?per_page=100'),
                  call_text(4).include?('pulls/42/comments/4031740163/replies'), sent_body(4)]
  end

  def test_an_inline_reply_reuses_its_key_only_within_the_same_thread
    matching = keyed(7, "<!-- shaka:reply:fix-1 -->\nold").merge('in_reply_to_id' => 4_031_740_163)
    other = keyed(8, "<!-- shaka:reply:fix-1 -->\nother").merge('in_reply_to_id' => 99)
    github = client(pull_response(''), viewer_response, response([other, matching]), html_response('<p>ok</p>'),
                    response({ 'id' => 7, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1', comment: 4_031_740_163)
    assert_equal ['PATCH', true], [sent_method(4), call_text(4).include?('pulls/comments/7')]
  end

  def test_an_invalid_inline_comment_id_never_contacts_github
    assert_raises(Shaka::Error) { client.reply(body: BODY, key: 'fix-1', comment: 0) }
    assert_empty @calls
  end

  def test_replies_reuse_their_keyed_comment_instead_of_duplicating_it
    listed = response([keyed(7, "<!-- shaka:reply:fix-1 -->\nold")])
    github = client(pull_response(''), viewer_response, listed, html_response('<p>ok</p>'),
                    response({ 'id' => 7, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1')
    assert_equal 'PATCH', sent_method(4)
    assert_includes @calls[4].first.join(' '), 'issues/comments/7'
  end

  def test_a_reply_without_an_existing_comment_is_created_once
    github = client(pull_response(''), viewer_response, response([]), html_response('<p>ok</p>'),
                    response({ 'id' => 9, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1')
    assert_equal 'POST', sent_method(4)
  end

  def test_an_invalid_reply_key_never_contacts_github
    ['', 'has space', 'a' * 65, nil].each do |key|
      assert_raises(Shaka::Error) { client.reply(body: BODY, key: key) }
      assert_empty @calls
    end
  end

  def test_a_comment_written_by_someone_else_is_never_overwritten
    listed = response([keyed(7, "<!-- shaka:reply:fix-1 -->\ntheirs", 'a-contributor')])
    github = client(pull_response(''), viewer_response, listed, html_response('<p>ok</p>'),
                    response({ 'id' => 9, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1')
    assert_equal 'POST', sent_method(4)
  end

  def test_a_marker_quoted_inside_a_comment_is_never_overwritten
    listed = response([keyed(7, 'quoting <!-- shaka:reply:fix-1 --> in passing')])
    github = client(pull_response(''), viewer_response, listed, html_response('<p>ok</p>'),
                    response({ 'id' => 9, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1')
    assert_equal 'POST', sent_method(4)
  end

  def test_a_separator_row_inside_a_code_fence_is_not_expected_to_render
    documented = "#{BODY}\n```\n| A | B |\n| --- | --- |\n```\n"
    managed = "<!-- shaka:begin -->\n#{documented}<!-- shaka:end -->"
    github = client(pull_response(''), html_response('<pre>| --- | --- |</pre>'), pull_response(''),
                    pull_response(managed))
    assert_equal managed, github.description(body: documented)['body']
  end

  def test_escape_sequences_inside_rendered_code_are_allowed
    github = client(pull_response(''), html_response('<p>Use <code>\\n</code> here.</p>'), pull_response(''),
                    pull_response(MANAGED))
    assert_equal MANAGED, github.description(body: BODY)['body']
  end

  def test_a_number_that_is_not_a_pull_request_is_refused_before_any_comment_is_touched
    github = client(response({}, status: 1))
    assert_raises(Shaka::Error) { github.reply(body: BODY, key: 'fix-1') }
    assert_equal 1, @calls.size
  end
end

# The reply listing must page with flags gh actually accepts.
class GitHubReplyPaginationTest < Minitest::Test
  include PublicationFixtures

  def test_the_reply_listing_uses_flags_gh_accepts
    github = client(pull_response(''), viewer_response, response([]), html_response('<p>ok</p>'),
                    response({ 'id' => 9, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1')
    listing = call_text(2)
    refute_includes listing, '--slurp'
    refute_includes listing, '--paginate'
    assert_includes listing, 'per_page=100'
    assert_includes listing, 'page=1'
  end

  def test_replies_are_fetched_across_every_page
    existing = keyed(7, "<!-- shaka:reply:fix-1 -->\nold")
    github = client(pull_response(''), viewer_response, response(full_page), response([existing]),
                    html_response('<p>ok</p>'),
                    response({ 'id' => 7, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1')
    assert_includes call_text(3), 'page=2'
    assert_equal ['PATCH', true], [sent_method(5), call_text(5).include?('issues/comments/7')]
  end

  def test_a_short_page_ends_the_reply_listing
    github = client(pull_response(''), viewer_response, response([keyed(6, 'first page')]),
                    html_response('<p>ok</p>'),
                    response({ 'id' => 9, 'body' => "<!-- shaka:reply:fix-1 -->\n#{BODY}" }))
    github.reply(body: BODY, key: 'fix-1')
    assert_equal 5, @calls.size
  end

  def test_a_comment_listing_that_is_not_an_array_is_reported
    github = client(pull_response(''), viewer_response, response({ 'message' => 'Not Found' }))
    assert_raises(Shaka::Error) { github.reply(body: BODY, key: 'fix-1') }
  end
end
