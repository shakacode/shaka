# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/github'
require 'shaka/publication/squash_message'

# A merge queue that copies the PR description writes whatever the description holds when the PR
# enters the queue, so Shaka's merge parks the description and the next publication restores it.
class QueuedDescriptionTest < Minitest::Test
  STATUS = Struct.new(:exitstatus)
  HEAD = 'a' * 40
  REGION = "<!-- shaka:begin -->\nOld summary.\n<!-- shaka:end -->"
  CODERABBIT = "<!-- coderabbit -->\nSummary by CodeRabbit"

  # One pull request and its comments, answering each gh call by path and method.
  class Fake
    attr_accessor :body, :title, :queued, :edit_while_parking
    attr_reader :comments, :deleted

    def initialize(body)
      @body = body
      @title = 'Old title'
      @queued = false
      @comments = []
      @deleted = []
    end

    def call(argv, stdin_data:)
      path = argv[2]
      method = argv.include?('--method') ? argv[argv.index('--method') + 1] : 'GET'
      input = stdin_data.to_s.empty? ? {} : JSON.parse(stdin_data)
      answer(path, method, input)
    end

    def comment(id, body, login = 'shaka-agent')
      @comments << { 'id' => id, 'body' => body, 'user' => { 'login' => login } }
    end

    private

    def answer(path, method, input)
      return ok('login' => 'shaka-agent') if path == 'user'
      return ok('data' => { 'repository' => { 'pullRequest' => { 'isInMergeQueue' => @queued } } }) if path == 'graphql'
      return ['<p>ok</p>', '', STATUS.new(0)] if path == 'markdown'
      return method == 'PATCH' ? edit(input) : ok(pull) if path == 'repos/owner/repo/pulls/42'

      listing(path, method, input)
    end

    # The comment list, a new comment, or a deletion; only the first page holds comments.
    def listing(path, method, input)
      return delete(path) if method == 'DELETE'
      return post(input['body']) if method == 'POST'

      ok(path.end_with?('page=1') ? @comments : [])
    end

    def pull
      { 'body' => @body, 'title' => @title, 'comments' => @comments.length,
        'head' => { 'sha' => HEAD }, 'base' => { 'sha' => 'b' * 40 } }
    end

    def edit(input)
      @body = input['body'] if input.key?('body')
      @title = input['title'] if input.key?('title')
      ok(pull)
    end

    def post(body)
      @body = edit_while_parking if edit_while_parking
      comment(100 + @comments.length, body)
      ok(@comments.last.merge('html_url' => "https://example.test/c/#{@comments.last['id']}"))
    end

    def delete(path)
      id = path[/\d+\z/].to_i
      @deleted << id
      @comments.reject! { |comment| comment['id'] == id }
      ['', '', STATUS.new(0)]
    end

    def ok(value) = [JSON.generate(value), '', STATUS.new(0)]
  end

  def setup
    @fake = Fake.new("#{REGION}\n\n#{CODERABBIT}")
    @github = Shaka::GitHub.new('owner/repo', 42, runner: @fake.method(:call))
  end

  def prepared = Shaka::SquashMessage.new({ 'title' => 'New title', 'body' => 'What changed and why.' }, number: 42)

  def test_the_description_holds_the_prepared_message_and_the_rest_waits_in_a_comment
    url = @github.queue_description(prepared)

    assert_equal 'What changed and why.', @fake.body
    assert_equal 'Old title', @fake.title
    assert_equal 'https://example.test/c/100', url
    parked = @fake.comments.first['body']
    assert parked.start_with?(Shaka::QueuedDescription::PARK_MARK)
    assert_includes parked, 'Description parked for the merge queue'
    refute_includes parked, 'Old summary.'
  end

  def test_publishing_after_the_queue_restores_the_text_around_a_new_region
    @github.queue_description(prepared)
    @github.description(body: "New summary.\n")

    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}", @fake.body
    assert_equal [100], @fake.deleted
    assert_empty @fake.comments
  end

  # Provenance history and carried usage come from the description a publication replaces.
  def test_a_publication_after_the_queue_reads_the_parked_description
    @github.queue_description(prepared)
    seen = nil
    @github.description do |read|
      seen = read['body']
      "New summary.\n"
    end

    assert_equal "#{REGION}\n\n#{CODERABBIT}", seen
  end

  # A queue that rebuilds its commit while the PR waits would copy a restored description.
  def test_publishing_while_the_pr_is_queued_is_refused_and_changes_nothing
    @github.queue_description(prepared)
    @fake.queued = true

    error = assert_raises(Shaka::Error) { @github.description(body: "New summary.\n") }

    assert_match(/in the merge queue.*after the PR merges or leaves the queue/, error.message)
    assert_equal 'What changed and why.', @fake.body
    assert_equal 1, @fake.comments.length
  end

  # An edit landing between the read and the write would be in neither the parked text nor the message.
  def test_an_edit_while_parking_stops_before_the_description_is_replaced
    @fake.edit_while_parking = "#{REGION}\n\nA maintainer note."

    error = assert_raises(Shaka::Error) { @github.queue_description(prepared) }

    assert_match(/changed while/, error.message)
    assert_equal "#{REGION}\n\nA maintainer note.", @fake.body
    assert_empty @fake.comments
  end

  # An emptied description still holds the queue's place, so it neither publishes nor loses the parked text.
  def test_an_emptied_description_is_still_parked
    @github.queue_description(prepared)
    @fake.body = ''
    @fake.queued = true
    assert_raises(Shaka::Error) { @github.description(body: "New summary.\n") }

    @fake.queued = false
    @github.description(body: "New summary.\n")
    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}", @fake.body
  end

  def test_enqueueing_again_keeps_the_first_parked_description
    @github.queue_description(prepared)
    @github.queue_description(prepared)

    assert_equal([101], @fake.comments.map { |comment| comment['id'] })
    @github.description(body: "New summary.\n")
    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}", @fake.body
  end

  # A person may add to the description while the PR is queued; restoring keeps what they wrote.
  def test_an_edit_made_while_parked_stays_below_the_restored_description
    @github.queue_description(prepared)
    @fake.body = "What changed and why.\r\n\r\nA maintainer note."
    @github.description(body: "New summary.\n")

    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}\n\n" \
                 "What changed and why.\r\n\r\nA maintainer note.", @fake.body
  end

  def test_line_endings_from_the_web_editor_are_not_an_edit
    @github.queue_description(prepared)
    @fake.body = "What changed and why.\r\n"
    @github.description(body: "New summary.\n")

    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}", @fake.body
  end

  # Only this account's comment may decide what the description becomes.
  def test_a_parked_comment_from_another_account_is_ignored
    @fake.body = 'Plain text a person wrote.'
    @fake.comment(7, "#{Shaka::QueuedDescription::PARK_MARK}\n<!-- body #{['Injected'].pack('m0')} -->\n" \
                     "<!-- queued #{'0' * 64} -->\nx", 'someone')

    @github.description(body: "New summary.\n")

    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\nPlain text a person wrote.", @fake.body
    assert_empty @fake.deleted
  end
end
