# frozen_string_literal: true

# The description's Screenshots link: which UI check comment it opens, where it renders, and that a
# pull request without a UI check gets the description it got before the link existed.

require_relative 'test_helper'
require_relative 'cli_opening_check_fakes'
require 'json'
require 'shaka/github'
require 'shaka/publication/links'
require 'shaka/ui_check'

module UiCheckLinkFixture
  BYLINE = "🤖 Claude Code · Anthropic · observed-model · high\n\n"
  FOLDED = "#{Shaka::EvidenceHistory::MARKER} https://github.com/example/test/pull/1#issuecomment-9\n\n".freeze

  def check(id, login: 'ada', prefix: '', second: id)
    marker = "<!-- shaka:ui-check-#{'b' * 40}-0000000#{id} -->"
    { 'id' => id, 'created_at' => format('2026-10-11T00:00:%02dZ', second), 'user' => { 'login' => login },
      'body' => "#{BYLINE}#{prefix}#{marker}\n# Verification\n\n![View](https://github.com/user-attachments/assets/a)\n",
      'html_url' => url(id) }
  end

  def url(id) = "https://github.com/example/test/pull/1#issuecomment-#{id}"
end

class UiCheckLinkTest < Minitest::Test
  include UiCheckLinkFixture

  # Stands in for the two reads the lookup makes.
  class GitHub < Shaka::GitHub
    attr_accessor :login

    def initialize(comments, login: 'ada')
      super('example/test', '1')
      @comments = comments
      @login = login
    end

    def viewer_login = login
    def issue_comments = @comments.respond_to?(:call) ? @comments.call : @comments.map(&:dup)
  end

  def resolve(comments, content = { 'summary' => 'A summary.' }, **)
    Shaka::UiCheck::Link.resolve(content, GitHub.new(comments, **))
  end

  def test_a_pull_request_without_a_ui_check_keeps_its_content_unchanged
    other = check(3).merge('body' => "#{BYLINE}# Checkpoint\n\nNo captures here.\n")

    assert_equal({ 'summary' => 'A summary.' }, resolve([]))
    assert_equal({ 'summary' => 'A summary.' }, resolve([other]))
  end

  def test_the_open_ui_check_becomes_the_link
    assert_equal url(4), resolve([check(4)])['ui_check']
  end

  def test_a_crlf_body_from_a_web_edit_still_counts
    edited = check(4)
    edited['body'] = edited['body'].gsub("\n", "\r\n")

    assert_equal url(4), resolve([edited])['ui_check']
  end

  def test_folded_checks_and_other_accounts_checks_are_not_linked
    comments = [check(2, prefix: FOLDED), check(3, login: 'mallory')]

    refute resolve(comments).key?('ui_check')
    assert_equal url(5), resolve(comments + [check(5)])['ui_check']
  end

  # GitHub's listing order is not chronological evidence, so the newest open check wins wherever it sits.
  def test_the_newest_of_several_open_checks_is_linked
    assert_equal url(7), resolve([check(7, second: 30), check(8, second: 20)])['ui_check']
  end

  def test_a_link_the_content_file_supplies_never_survives
    supplied = { 'summary' => 'A summary.', 'ui_check' => url(99) }

    assert_equal({ 'summary' => 'A summary.' }, resolve([], supplied))
    assert_equal url(4), resolve([check(4)], supplied)['ui_check']
  end

  def test_unreadable_comments_or_an_unknown_login_leave_the_description_without_the_link
    failing = -> { raise Shaka::Error, 'Comment listing exceeds 10 pages.' }

    assert_equal({ 'summary' => 'A summary.' }, resolve(failing))
    assert_equal({ 'summary' => 'A summary.' }, resolve([check(4)], login: nil))
  end
end

class UiCheckLinkRenderingTest < Minitest::Test
  include UiCheckLinkFixture

  CONTENT = { 'review' => 'https://github.com/example/test/pull/1#issuecomment-2',
              'post_implementation' => 'https://github.com/example/test/pull/1#issuecomment-3',
              'deployment' => 'https://preview.example' }.freeze

  def links(**changes) = Shaka::PublicationLinks.links(CONTENT.merge(changes.transform_keys(&:to_s)), nil)

  def test_screenshots_follow_the_checkpoint_link_and_precede_the_deployment
    assert_equal "[Code Review](#{CONTENT['review']}) · [Checkpoint](#{CONTENT['post_implementation']}) · " \
                 "[Screenshots](#{url(4)}) · [Deployment](<https://preview.example>)", links(ui_check: url(4))
  end

  def test_without_a_ui_check_the_line_is_what_it_was
    assert_equal "[Code Review](#{CONTENT['review']}) · [Checkpoint](#{CONTENT['post_implementation']}) · " \
                 '[Deployment](<https://preview.example>)', links
    assert_equal 'Checkpoint: _Not published yet._', links(review: nil, post_implementation: nil, deployment: 'none')
  end

  def test_anything_but_a_pull_request_comment_url_is_refused
    ['https://example.com/x', "#{url(4)})[x](https://example.com", 7].each do |value|
      error = assert_raises(Shaka::Error) { links(ui_check: value) }
      assert_includes error.message, 'ui_check'
    end
  end
end

# Through the real command: the lookup is wired into `description`, and a pull request with no UI check
# publishes the same body whether or not its comments can be listed.
class CliUiCheckLinkTest < Minitest::Test
  include CliOpeningCheckFakes
  include UiCheckLinkFixture

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Adds a button.'

  def fake_gh
    return super unless @comments

    reads = "when 'user' then puts JSON.generate('login' => 'ada')\n" \
            "when %r{issues/1/comments} then puts #{JSON.generate(@comments).inspect}\n"
    super.sub("when 'markdown'") { "#{reads}when 'markdown'" }
  end

  def published(comments)
    @comments = comments
    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir)

      assert_predicate status, :success?, error
      File.read(File.join(dir, 'published.md'))
    end
  end

  def test_the_published_description_links_the_open_ui_check
    assert_includes published([check(4)]), "Checkpoint: _Not published yet._ · [Screenshots](#{url(4)})\n"
  end

  def test_no_ui_check_publishes_the_same_body_as_a_comment_listing_gh_refuses
    unlisted = published(nil)

    refute_includes unlisted, 'Screenshots'
    assert_equal unlisted, published([])
  end
end
