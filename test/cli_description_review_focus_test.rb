# frozen_string_literal: true

# Proves description links a review focus range at the PR head through the real command.

require_relative 'test_helper'
require_relative 'cli_opening_check_fakes'
require 'json'

class CliDescriptionReviewFocusTest < Minitest::Test
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Guards queue submission.'
  HEAD = 'c' * 40
  SOURCE = "class Queue\n  def submit\n    check\n  end\nend\n"

  def description_content
    focus = [{ 'path' => 'lib/queue.rb', 'level' => 4, 'reason' => 'submits the queue entry.',
               'from' => 'def submit', 'block' => true }]
    super.merge('intent' => INTENT.merge('review_focus' => focus))
  end

  def fake_gh
    <<~RUBY
      require 'json'
      raw = STDIN.read
      request = raw.strip.empty? ? {} : JSON.parse(raw)
      case ARGV[1]
      when 'repos/owner/repo/pulls/1'
        if ARGV.include?('PATCH')
          File.write(File.join(ENV.fetch('HOME'), 'published.md'), request.fetch('body'))
          puts JSON.generate(request)
        else
          puts JSON.generate('body' => '', 'head' => { 'sha' => '#{HEAD}' }, 'changed_files' => 1,
                             'additions' => 5, 'deletions' => 0)
        end
      when %r{pulls/1/files}
        puts JSON.generate([{ 'filename' => 'lib/queue.rb', 'status' => 'added' }])
      when 'repos/owner/repo/contents/lib?ref=#{HEAD}'
        puts JSON.generate([{ 'name' => 'queue.rb', 'type' => 'file' }])
      when 'repos/owner/repo/contents/lib/queue.rb?ref=#{HEAD}'
        puts JSON.generate('type' => 'file', 'encoding' => 'base64', 'content' => [#{SOURCE.inspect}].pack('m'))
      when 'markdown' then puts JSON.generate('<table></table>' * 10)
      when 'graphql'
        references = { 'totalCount' => 0, 'nodes' => [] }
        puts JSON.generate('data' => { 'repository' => { 'pullRequest' => { 'closingIssuesReferences' => references } } })
      else abort "unexpected gh request: \#{ARGV.inspect}"
      end
    RUBY
  end

  def test_a_focus_range_is_linked_at_the_head_under_review_effort
    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir)

      assert_predicate status, :success?, error
      link = "[`lib/queue.rb` lines 2–4](https://github.com/owner/repo/blob/#{HEAD}/lib/queue.rb#L2-L4)"
      assert_includes File.read(File.join(dir, 'published.md')),
                      "**Closer reading:**\n- 4 of 5: #{link}, submits the queue entry."
    end
  end
end
