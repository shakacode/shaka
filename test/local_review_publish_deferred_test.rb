# frozen_string_literal: true

require_relative 'local_review_commit_publish_test'
require 'shaka/github'

# `review publish` where GitHub refuses its Markdown renderer checks each stored part instead.
class LocalReviewPublishDeferredTest < Minitest::Test
  include LocalReviewCommentFixture

  STATUS = Struct.new(:exitstatus)

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

  # Break caught: the stored check and the review layout check disagree on GitHub's stored markup.
  def test_a_real_reply_accepts_github_markup_for_a_review_part_and_deletes_a_flattened_one
    part = loop_part
    assert stored_reply(part, autolinked(LocalReviewCommitPublishTest::Timeline.new.markdown(part.body)))

    error = assert_raises(Shaka::Error) { stored_reply(part, '<p>flattened</p>') }
    assert_includes error.message, 'The comment was deleted.'
  end

  private

  def loop_part
    Shaka::LocalReviewLoopComment.new({ 'rounds' => [round] }, repository: 'o/r', usage_url: 'https://github.com/o/r/pull/7',
                                                               published: ->(_) { true }, rebased: ->(_) {},
                                                               subject: ->(_) { 'Subject' }).parts.first
  end

  # GitHub's stored markup: direction attributes, and the attestation's SHA shown as an abbreviated commit link.
  def autolinked(html)
    html.gsub(/<(p|summary)>/, '<\\1 dir="auto">').sub(/REVIEWED (\h{40})/) do
      sha = Regexp.last_match(1)
      %(REVIEWED <a class="commit-link" href="https://github.com/o/r/commit/#{sha}"><tt>#{sha[0, 7]}</tt></a>)
    end
  end

  def stored_reply(part, html)
    Shaka::GitHub.new('o/r', 7, runner: stored_runner(html))
                 .reply(body: part.body, key: part.key, verbatim: part.reports,
                        stored_check: part.method(:check_rendering!))
  end

  # Refuses the renderer and stores each write with `html` as GitHub's rendering of it.
  def stored_runner(html)
    reads = { 'user' => { 'login' => 'agent' }, 'repos/o/r/pulls/7' => { 'number' => 7 } }
    lambda do |argv, stdin_data:|
      next ['', 'gh: refused (HTTP 403)', STATUS.new(1)] if argv[2] == 'markdown'
      next ['', '', STATUS.new(0)] if argv.include?('DELETE')

      reply = reads.fetch(argv[2]) { argv[2].include?('/comments?') ? [] : stored(stdin_data, html) }
      [JSON.generate(reply), '', STATUS.new(0)]
    end
  end

  def stored(stdin_data, html)
    { 'id' => 3, 'body' => JSON.parse(stdin_data)['body'], 'body_html' => html,
      'html_url' => 'u' }
  end

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
