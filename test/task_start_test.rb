# frozen_string_literal: true

require_relative 'github_publication_test'
require 'shaka/task_start'
require 'json'
require 'open3'
require 'tmpdir'

# A task's start comment carries the WIP Details fields on the issue the task answers.
class TaskStartTest < Minitest::Test
  include PublicationFixtures

  WIP = { 'owner' => 'm5 · Claude desktop · k7q2', 'task' => 'SHAKA #42 · start comment',
          'thread' => 'UNKNOWN', 'last_observed_activity' => '2026-10-28 10:15 HST',
          'revision' => 'jg/42-start @ 57e2f31b30db1234567890abcdef1234567890ab',
          'workspace' => '/work/shaka-wt-42', 'unfinished_work' => 'none', 'stopped_because' => 'running',
          'merge_authority' => 'ask', 'state' => 'In progress: implementing', 'next_action' => 'Write the test' }.freeze
  CONTENT = { 'identity' => { 'agent' => 'Claude Code' }, 'summary' => 'Started work on this issue.',
              'wip' => WIP }.freeze

  def test_the_body_holds_the_summary_and_every_wip_field
    body = Shaka::TaskStart.compose(CONTENT)

    assert_includes body, 'Started work on this issue.'
    assert_includes body, '<summary>WIP Details</summary>'
    Shaka::WipDetails::FIELDS.each_value { |label| assert_includes body, "| #{label} |" }
    assert_includes body, '/work/shaka-wt-42'
  end

  def test_the_checkout_path_follows_the_repository_redaction
    body = Shaka::TaskStart.compose(CONTENT, path_redaction: 'REDACTED')

    assert_includes body, '| Workspace | REDACTED |'
    refute_includes body, '/work/shaka-wt-42'
  end

  def test_content_needs_wip_and_refuses_other_fields
    assert_includes assert_raises(Shaka::Error) { Shaka::TaskStart.compose(CONTENT.except('wip')) }.message, 'wip'
    error = assert_raises(Shaka::Error) { Shaka::TaskStart.compose(CONTENT.merge('sections' => [])) }
    assert_includes error.message, 'sections'
  end

  def test_the_key_names_the_owner_tag_so_a_new_owner_posts_its_own
    assert_equal 'start-k7q2', Shaka::TaskStart.key(CONTENT)
    assert_equal 'start', Shaka::TaskStart.key(CONTENT.merge('wip' => WIP.merge('owner' => 'UNKNOWN')))
  end

  def test_the_comment_is_posted_on_the_issue_and_a_retry_updates_it
    github = retry_client("<!-- shaka:reply:start-k7q2 -->\n#{BODY}")

    assert_equal [9, 9], [start(github, BODY), start(github, BODY.sub('A summary.', 'Resumed.'))]

    assert_includes call_text(4), 'repos/owner/repo/issues/42/comments'
    assert_equal %w[POST PATCH], [sent_method(4), sent_method(8)]
    refute(@calls.any? { |argv, _input| argv.join(' ').include?('pulls/42') })
  end

  def test_a_pull_request_is_refused_before_anything_is_written
    github = client(issue_response('pull_request' => { 'url' => 'x' }))

    error = assert_raises(Shaka::Error) { start(github, BODY) }

    assert_includes error.message, 'WIP Details'
    assert_equal 1, @calls.size
  end

  def test_the_command_needs_a_trusted_ref_before_it_calls_github
    Dir.mktmpdir do |dir|
      sentinel = File.join(dir, 'called')
      File.write(File.join(dir, 'gh'), "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
      File.chmod(0o755, File.join(dir, 'gh'))
      _output, error, status = start_command(dir)

      refute_predicate status, :success?
      assert_includes error, 'start requires --ref'
      refute_path_exists sentinel
    end
  end

  private

  def start_command(dir)
    path = File.join(dir, 'content.json')
    File.write(path, JSON.generate(CONTENT))
    Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}" }, *SHAKA_COMMAND, 'start', 'owner/repo', '42',
                   '--content-file', path)
  end

  def start(github, body) = github.reply(body:, key: 'start-k7q2', issue: true)['id']

  def retry_client(posted)
    client(issue_response, viewer_response, response([]), html_response('<p>ok</p>'),
           response({ 'id' => 9, 'body' => posted }),
           issue_response, response([keyed(9, posted)]), html_response('<p>ok</p>'),
           response({ 'id' => 9, 'body' => posted.sub('A summary.', 'Resumed.') }))
  end

  def issue_response(extra = {}) = response({ 'number' => 42, 'title' => 'Task' }.merge(extra))
end
