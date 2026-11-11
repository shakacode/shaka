# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/github'

# A comment published where GitHub refuses `POST /markdown`, as Claude Code cloud sessions do.
class DeferredRenderingTest < Minitest::Test
  STATUS = Struct.new(:exitstatus)
  REFUSED = 'gh: This GitHub API path is not available: sessions are bound to their configured repositories. (HTTP 403)'
  FULL = 'Accept: application/vnd.github.full+json'
  URL = 'https://github.com/owner/repo/pull/42#issuecomment-9'
  COMMENTS = 'repos/owner/repo/issues/42/comments'

  def setup
    @calls = []
    @stored_html = '<p>Fine.</p>'
    @markdown = ['', REFUSED, STATUS.new(1)]
    @comments = []
  end

  def test_a_refused_renderer_checks_the_stored_comment_after_writing
    checked = []
    written = publish(stored_check: ->(html) { checked << html })

    assert_equal 9, written['id']
    assert_equal [@stored_html], checked
    assert_includes created.first.first, FULL
    refute_predicate self, :deleted?
  end

  def test_a_new_comment_that_fails_its_stored_check_is_deleted
    error = assert_raises(Shaka::Error) { publish(stored_check: ->(_) { raise Shaka::Error, 'Layout broke.' }) }

    assert_equal 'Layout broke. The comment was deleted.', error.message
    assert_predicate self, :deleted?
  end

  def test_a_changed_comment_that_fails_its_stored_check_gets_its_earlier_body_back
    @comments = [{ 'id' => 9, 'body' => "#{mark}\nOlder.", 'user' => { 'login' => 'agent' } }]
    @stored_html = '<p>no table</p>'
    error = assert_raises(Shaka::Error) { publish(body: "| a |\n| --- |\n| b |", stored_check: ->(_) {}) }

    assert_match(/rendered 0 of 1 table.*The comment was restored\.\z/, error.message)
    restore = @calls.find { |argv, input| argv.include?('PATCH') && JSON.parse(input)['body'] == "#{mark}\nOlder." }
    refute_nil restore
  end

  def test_an_unchanged_comment_is_read_back_and_never_rewritten
    @comments = [{ 'id' => 9, 'body' => "#{mark}\nHello.", 'user' => { 'login' => 'agent' }, 'html_url' => URL }]
    error = assert_raises(Shaka::Error) { publish(stored_check: ->(_) { raise Shaka::Error, 'Layout broke.' }) }

    assert_equal "Layout broke. The same text was already published at #{URL}.", error.message
    assert(@calls.any? { |argv, _| argv.include?('repos/owner/repo/issues/comments/9') && argv.include?(FULL) })
    refute(@calls.any? { |argv, _| argv.include?('PATCH') || argv.include?('DELETE') })
  end

  def test_missing_stored_rendering_takes_the_write_back
    @stored_html = nil
    error = assert_raises(Shaka::Error) { publish(stored_check: ->(_) {}) }

    assert_match(/no stored rendering.*deleted/, error.message)
  end

  def test_a_failed_undo_names_the_live_comment
    @delete_fails = true
    error = assert_raises(Shaka::Error) { publish(stored_check: ->(_) { raise Shaka::Error, 'Layout broke.' }) }

    assert_includes error.message, 'Undoing the write failed'
    assert_includes error.message, URL
  end

  def test_without_an_opt_in_a_refused_renderer_stops_before_writing
    error = assert_raises(Shaka::Error) { publish }

    assert_includes error.message, 'POST /markdown'
    assert_empty created
  end

  def test_other_renderer_failures_and_source_escapes_stop_before_writing
    @markdown = ['', 'gh: Bad credentials (HTTP 401)', STATUS.new(1)]
    assert_raises(Shaka::Error) { publish(stored_check: ->(_) {}) }
    @markdown = ['', REFUSED, STATUS.new(1)]
    ['Line one\nline two', 'Line one&#92;nline two', 'Use \`x \n\` ok'].each do |body|
      error = assert_raises(Shaka::Error) { publish(body:, stored_check: ->(_) {}) }
      assert_includes error.message, 'literal escape'
    end
    assert_empty created
  end

  def test_a_table_inside_a_quoted_report_cannot_stand_in_for_a_broken_one_around_it
    report = "| r |\n| --- |\n| s |"
    @stored_html = '<table></table>'
    body = "| a | b |\n| --- |\n| c |\n\n#{report}"
    error = assert_raises(Shaka::Error) { publish(body:, verbatim: [report], stored_check: ->(_) {}) }

    assert_match(/rendered 1 of 2 table.*deleted/, error.message)
  end

  def test_quoted_reports_and_generated_code_may_hold_escapes_the_surrounding_text_may_not
    report = 'Report says \n literally.'
    assert publish(body: "Intro.\n\n#{report}", verbatim: [report], stored_check: ->(_) {})
    assert publish(body: 'Subject <code>&#70;ix &#92;n handling</code>.', stored_check: ->(_) {})
  end

  private

  def mark = '<!-- shaka:reply:loop -->'

  def publish(body: 'Hello.', **)
    Shaka::GitHub.new('owner/repo', 42, runner: method(:answer)).reply(body:, key: 'loop', **)
  end

  def created = @calls.select { |argv, _| argv.include?(COMMENTS) && argv.include?('POST') }

  def deleted? = @calls.any? { |argv, _| argv.include?('DELETE') }

  def answer(argv, stdin_data:)
    @calls << [argv, stdin_data]
    path = argv[2]
    return @markdown if path == 'markdown'
    return delete_answer if argv.include?('DELETE')
    return json({ 'number' => 42 }) if path == 'repos/owner/repo/pulls/42'
    return json({ 'login' => 'agent' }) if path == 'user'
    return json(@comments) if path.start_with?('repos/owner/repo/issues/42/comments?')

    stored(argv, stdin_data)
  end

  def stored(argv, stdin_data)
    body = argv.include?('GET') ? @comments.first['body'] : JSON.parse(stdin_data)['body']
    json({ 'id' => 9, 'body' => body, 'html_url' => URL }.merge(@stored_html ? { 'body_html' => @stored_html } : {}))
  end

  def delete_answer = @delete_fails ? ['', 'gh: Server Error (HTTP 500)', STATUS.new(1)] : ['', '', STATUS.new(0)]
  def json(value) = [JSON.generate(value), '', STATUS.new(0)]
end
