# frozen_string_literal: true

# Proves the description command posts the overflow comment and links it when the body
# would exceed GitHub's limit (#878).

require_relative 'test_helper'
require_relative 'cli_opening_check_fakes'
require 'json'

class CliDescriptionOverflowTest < Minitest::Test
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Keeps the description under the limit.'
  NOTE = "Rate card note. #{'Priced from the local rate card. ' * 90}".freeze
  PLACEHOLDER = 'https://example.com/ooo'

  def test_an_overflowing_description_posts_and_links_the_details_comment
    Dir.mktmpdir do |dir|
      # Person-written text outside the managed region pushes the body just past the limit.
      @human = "#{'Notes a person wrote. ' * ((65_536 - fitting_length(dir) + 600) / 22)}\n"
      output, error, status = run_description(dir) { write_overflow_gh(dir) }

      assert_predicate status, :success?, "#{output}\n#{error}"
      assert_overflow_published(dir)
    end
  end

  private

  def fitting_length(dir)
    @human = ''
    _, error, status = run_description(dir) { write_overflow_gh(dir) }
    assert_predicate status, :success?, error
    File.read(File.join(dir, 'published.md')).length
  end

  def assert_overflow_published(dir)
    published = File.read(File.join(dir, 'published.md'))
    comment = File.read(File.join(dir, 'comment.md'))

    assert_operator published.length, :<=, 65_536
    assert_operator comment.length, :<=, 65_536
    assert comment.start_with?('<!-- shaka:reply:usage-timing-details -->'), comment[0, 200]
    assert_includes comment, 'How each report was measured and priced'
    assert_includes published, 'https://github.com/owner/repo/pull/1#issuecomment-7'
    refute_includes published, PLACEHOLDER
  end

  def description_content
    content = super
    records = content.dig('usage', 'records').map { |record| record.merge('note' => NOTE) }
    content.merge('usage' => content['usage'].merge('records' => records))
  end

  def write_overflow_gh(dir)
    File.write(File.join(dir, 'human.md'), @human)
    write_executable(dir, 'gh', overflow_gh)
  end

  def overflow_gh
    <<~RUBY
      require 'json'
      home = ENV.fetch('HOME')
      raw = STDIN.read
      request = raw.strip.empty? ? {} : JSON.parse(raw)
      method = ARGV[ARGV.index('--method') + 1] if ARGV.include?('--method')
      case ARGV[1]
      when 'repos/owner/repo/pulls/1'
        if method == 'PATCH'
          File.write(File.join(home, 'published.md'), request.fetch('body'))
          puts JSON.generate(request)
        else
          puts JSON.generate('body' => File.read(File.join(home, 'human.md')), 'number' => 1,
                             'head' => { 'sha' => 'c' * 40 }, 'changed_files' => 0)
        end
      when 'user' then puts JSON.generate('login' => 'shaka-agent')
      when %r{\\Arepos/owner/repo/issues/1/comments\\?} then puts '[]'
      when 'repos/owner/repo/issues/1/comments'
        File.write(File.join(home, 'comment.md'), request.fetch('body'))
        puts JSON.generate('id' => 7, 'body' => request.fetch('body'), 'user' => { 'login' => 'shaka-agent' },
                           'html_url' => 'https://github.com/owner/repo/pull/1#issuecomment-7')
      when %r{pulls/1/files?} then puts '[]'
      when 'markdown' then puts JSON.generate('<table></table>' * 10)
      when 'graphql'
        references = { 'totalCount' => 0, 'nodes' => [] }
        puts JSON.generate('data' => { 'repository' => { 'pullRequest' => { 'closingIssuesReferences' => references } } })
      else abort "unexpected gh request: \#{ARGV.inspect}"
      end
    RUBY
  end
end
