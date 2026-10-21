# frozen_string_literal: true

require 'json'

# One pull request and its comments, answering each gh call by path and method.
class QueuedDescriptionFake
  STATUS = Struct.new(:exitstatus)
  HEAD = 'a' * 40

  attr_accessor :body, :title, :queued, :edit_while_parking, :refuse_edit
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
    return ['', 'HTTP 422', STATUS.new(1)] if refuse_edit

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
