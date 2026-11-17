# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/github'
require 'shaka/publication/publication'
require 'shaka/walkthrough/due'

# The gates read the comment `shaka reply --key walkthrough-request` posts, so the body comes from that publisher.
class WalkthroughDueTest < Minitest::Test
  CONTENT = { 'identity' => { 'agent' => 'Codex' }, 'summary' => 'Justin asked for a published walkthrough.' }.freeze
  Reader = Struct.new(:account, :published?, :revision)

  def test_a_request_posted_by_reply_makes_a_walkthrough_due
    comment = { 'user' => { 'login' => 'ann' }, 'body' => posted_reply('walkthrough-request') }

    assert_predicate due(comment), :due?
  end

  def test_another_reply_key_makes_none_due
    comment = { 'user' => { 'login' => 'ann' }, 'body' => posted_reply('fix-1') }

    refute_predicate due(comment), :due?
  end

  private

  def due(comment)
    github = Struct.new(:issue_comments).new([comment])
    Shaka::WalkthroughDue.new(github, publish: 'on_request', reader: Reader.new('ann', false, nil))
  end

  # The body `shaka reply` sends to GitHub: its hidden key line, then the rendered comment.
  def posted_reply(key)
    sent = []
    answers = [{ 'body' => '' }, { 'login' => 'ann' }, [], '<p>ok</p>']
    runner = lambda do |_argv, stdin_data:|
      sent << stdin_data
      answer = answers.shift || JSON.parse(stdin_data)
      [answer.is_a?(String) ? answer : JSON.generate(answer), '', Struct.new(:exitstatus).new(0)]
    end
    Shaka::GitHub.new('owner/repo', 7, runner:).reply(body: Shaka::Publication.comment(CONTENT), key:)
    JSON.parse(sent.last).fetch('body')
  end
end
