# frozen_string_literal: true

require_relative 'claude_usage_test'
require 'open3'
require 'tmpdir'

# Runs the installed entry point against a fake GitHub that stores comments between processes.
class UsageJournalCliTest < Minitest::Test
  include ClaudeUsageFixture

  TARGET = %w[owner/repo 12].freeze

  def test_publish_then_collect_recovers_the_response_on_another_host_without_duplicates
    Dir.mktmpdir do |directory|
      file = transcript(directory, 'session.jsonl', [prompt('turn'), priced_reply('main', 100)])
      env = fake_github(directory)
      2.times { assert_command(env, *publish_arguments(file)) }
      assert_equal 1, comments(directory).size
      assert_collected(JSON.parse(assert_command(env.merge('CLAUDE_CODE_SESSION_ID' => ''), 'collect', *TARGET)))
    end
  end

  def test_an_outside_marker_is_ignored_while_the_writer_still_counts
    Dir.mktmpdir do |directory|
      file = transcript(directory, 'session.jsonl', [prompt('turn'), priced_reply('main', 100)])
      env = fake_github(directory)
      assert_command(env, *publish_arguments(file))
      original = comments(directory).first
      forged = original.merge('id' => 2, 'user' => { 'login' => 'outsider' },
                              'body' => original['body'].sub('"input":"100"', '"input":"9"'))
      save_comments(directory, [original, forged])
      assert_collected(JSON.parse(assert_command(env, 'collect', *TARGET)))
    end
  end

  private

  def publish_arguments(file)
    ['publish', *TARGET, '--host', 'claude-code', '--file', file, '--all-turns', '--commit', COMMIT,
     '--contribution', 'implementation', '--event', 'commit']
  end

  def assert_collected(document)
    record = document.fetch('records').first
    assert_equal 1, document.fetch('records').size
    assert_equal '100', record['columns'][0]['input']
    assert_equal 1, record['responses'].size
  end

  def assert_command(env, *)
    output, error, status = Open3.capture3(env, *Array(SHAKA_COMMAND), 'usage', *)
    assert_predicate status, :success?, error
    output
  end

  def comments(directory) = JSON.parse(File.read(File.join(directory, 'comments.json')))
  def save_comments(directory, rows) = File.write(File.join(directory, 'comments.json'), JSON.generate(rows))

  def fake_github(directory)
    bin = File.join(directory, 'bin')
    FileUtils.mkdir_p(bin)
    save_comments(directory, [])
    File.write(File.join(bin, 'gh'), gh_script(File.join(directory, 'comments.json')))
    File.chmod(0o755, File.join(bin, 'gh'))
    { 'PATH' => "#{bin}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}" }
  end

  def gh_script(store)
    <<~RUBY
      #!/usr/bin/env ruby
      require 'json'
      raw = STDIN.read
      stored = JSON.parse(File.read(#{store.dump}))
      if ARGV.include?('markdown')
        tables = JSON.parse(raw).fetch('text').lines.count { |line| line.match?(/\\A\\s*\\|[\\s|:-]*-{3}[\\s|:-]*\\|\\s*\\z/) }
        puts '<p>Rendered.</p>' + ('<table></table>' * tables)
      elsif ARGV[1].include?('/permission')
        login = ARGV[1][%r{collaborators/([^/]+)/}, 1]
        puts JSON.generate('permission' => login == 'writer' ? 'write' : 'read', 'user' => { 'login' => login })
      elsif ARGV.include?('POST')
        row = JSON.parse(raw).merge('id' => stored.size + 1, 'user' => { 'login' => 'writer' })
        File.write(#{store.dump}, JSON.generate(stored + [row]))
        puts JSON.generate(row)
      else
        puts JSON.generate(ARGV[1].include?('page=1') ? stored : [])
      end
    RUBY
  end
end
