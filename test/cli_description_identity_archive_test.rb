# frozen_string_literal: true

# Proves `shaka description` signs usage archive comments with the identity it rendered, whose
# first line in the description leaves out the fields that were not read.

require_relative 'test_helper'
require_relative 'cli_opening_check_fakes'
require 'shaka/publication/agent_post'
require 'json'

class CliDescriptionIdentityArchiveTest < Minitest::Test
  include CliOpeningCheckFakes

  COMMAND = SHAKA_COMMAND
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Archive comments keep the writer.'
  RESPONSES = Array.new(6000) { |index| "response-#{index}" }.freeze
  # Stores each archive comment the command posts and serves it back when the command reads it.
  COMMENTS = <<~RUBY
    when 'repos/owner/repo/issues/1/comments'
      store = File.join(ENV.fetch('HOME'), 'comments')
      Dir.mkdir(store) unless Dir.exist?(store)
      id = Dir[File.join(store, '*.json')].size + 1
      comment = { 'id' => id, 'body' => request.fetch('body'),
                  'issue_url' => 'https://api.github.com/repos/owner/repo/issues/1' }
      File.write(File.join(store, "\#{id}.json"), JSON.generate(comment))
      puts JSON.generate(comment)
    when %r{\\Arepos/owner/repo/issues/comments/(\\d+)\\z}
      puts File.read(File.join(ENV.fetch('HOME'), 'comments', "\#{Regexp.last_match(1)}.json"))
  RUBY
  FILES = 'when %r{pulls/1/files?}'

  def test_archive_comments_carry_every_identity_field_the_short_first_line_leaves_out
    Dir.mktmpdir do |dir|
      _output, error, status = publish(dir)

      assert_predicate status, :success?, error
      assert_equal '🤖 Codex · OpenAI · high - AI spend: UNKNOWN', opening(dir)
      comments = posted(dir)
      refute_empty comments
      assert_equal ['🤖 Codex · OpenAI · UNKNOWN · high'], comments.map { it.lines.first.chomp }.uniq
      assert(comments.all? { Shaka::AgentPost.marked?(it) })
    end
  end

  private

  def opening(dir) = File.read(File.join(dir, 'published.md'))[/^🤖 [^\n]+/]
  def posted(dir) = Dir[File.join(dir, 'comments', '*.json')].map { JSON.parse(File.read(it)).fetch('body') }

  def publish(dir)
    write_fake_commands(dir)
    content = File.join(dir, 'content.json')
    File.write(content, JSON.generate(description_content))
    environment = SESSION_ENV_CLEARED.merge('PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir)
    Open3.capture3(environment, *COMMAND, 'description', 'owner/repo', '1', '--root', ROOT, '--content-file', content)
  end

  def description_content
    usage = USAGE.merge('records' => [USAGE.fetch('records').first.merge('responses' => RESPONSES)])
    super.merge('identity' => { 'agent' => 'Codex', 'provider' => 'OpenAI', 'effort' => 'high' }, 'usage' => usage)
  end

  def fake_gh
    replaced = super.sub(FILES, "#{COMMENTS}#{FILES}")
    raise 'fake gh was not extended' if replaced == super

    replaced
  end
end
