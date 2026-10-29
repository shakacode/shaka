# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github'
require 'shaka/post_implementation/stale'

class PostImplementationStaleTest < Minitest::Test
  OLD = 'a' * 40
  NEW = 'b' * 40

  class GitHub < Shaka::GitHub
    attr_reader :minimized, :mutations
    attr_accessor :head, :state, :comments, :permission, :failure

    def initialize(comments)
      super('example/test', 1)
      @comments = comments
      @head = NEW
      @state = 'OPEN'
      @permission = true
      @minimized = {}
      @mutations = []
    end

    def snapshot = { 'state' => state, 'headRefOid' => head }

    def viewer_login = 'ada'

    def issue_comments = comments

    def graphql(query, id:, **)
      raise Shaka::Error, 'GraphQL failed' if failure
      return mutate(id) if query.include?('mutation')

      { 'node' => { 'id' => id, 'isMinimized' => minimized.fetch(id, false), 'viewerCanMinimize' => permission } }
    end

    def mutate(id)
      @mutations << id
      @minimized[id] = true
      {}
    end
  end

  def test_minimizes_newest_checkpoint_after_the_head_moves
    github = GitHub.new([checkpoint(1, OLD), checkpoint(2, OLD)])

    assert_equal({ 'state' => 'minimized', 'comment' => 2 }, Shaka::PostImplementationStale.new(github).call)
    assert_equal ['N_2'], github.mutations
  end

  def test_leaves_checkpoint_for_the_live_head_visible
    github = GitHub.new([checkpoint(1, OLD), checkpoint(2, NEW)])

    assert_equal({ 'state' => 'current', 'comment' => 2 }, Shaka::PostImplementationStale.new(github).call)
    assert_empty github.mutations
  end

  def test_compares_the_full_attested_head_not_its_short_prefix
    github = GitHub.new([checkpoint(2, "abcdef0#{'1' * 33}")])
    github.head = "abcdef0#{'2' * 33}"

    assert_equal 'minimized', Shaka::PostImplementationStale.new(github).call['state']
  end

  def test_repeat_run_does_not_minimize_again
    github = GitHub.new([checkpoint(2, OLD)])
    github.minimized['N_2'] = true

    assert_equal 'already_minimized', Shaka::PostImplementationStale.new(github).call['state']
    assert_empty github.mutations
  end

  def test_ignores_other_accounts_and_closed_pull_requests
    github = GitHub.new([checkpoint(3, OLD, login: 'someone-else')])
    assert_equal({ 'state' => 'none' }, Shaka::PostImplementationStale.new(github).call)

    github.comments = [checkpoint(2, OLD)]
    github.state = 'MERGED'
    assert_equal({ 'state' => 'none' }, Shaka::PostImplementationStale.new(github).call)
    assert_empty github.mutations
  end

  def test_reports_a_refused_minimize_instead_of_failing
    github = GitHub.new([checkpoint(2, OLD)])
    github.permission = false

    result = Shaka::PostImplementationStale.new(github).call
    assert_equal 'unavailable', result['state']
    assert_match(/does not permit/, result['reason'])

    github.failure = true
    assert_equal 'GraphQL failed', Shaka::PostImplementationStale.new(github).call['reason']
  end

  private

  def checkpoint(id, head, login: 'ada')
    { 'id' => id, 'node_id' => "N_#{id}", 'user' => { 'login' => login },
      'created_at' => "2026-10-0#{id}T00:00:00Z",
      'body' => "<!-- shaka:reply:post-implementation-#{head[0, 7]}-0123abcd -->\n🤖 Checkpoint\n" \
                "<!-- shaka:post-implementation #{head} ready -->\n" }
  end
end

class PostImplementationStaleCliTest < Minitest::Test
  # Answers only the calls `attention --state none` makes, and records each write in HOME.
  FAKE_GH = <<~RUBY
    require 'json'
    home = ENV.fetch('HOME')
    request = JSON.parse(STDIN.read.then { |raw| raw.strip.empty? ? '{}' : raw })
    log = ->(line) { File.write(File.join(home, 'writes'), "\#{line}\\n", mode: 'a') }
    path = ARGV[1]
    if path == 'graphql'
      query = request.fetch('query')
      if query.include?('minimizeComment')
        log.call("minimize \#{request.dig('variables', 'id')}")
        puts JSON.generate('data' => {})
      elsif query.include?('node(id:')
        minimized = File.exist?(File.join(home, 'writes')) && File.read(File.join(home, 'writes')).include?('minimize')
        node = { 'id' => 'N_2', 'isMinimized' => minimized, 'viewerCanMinimize' => true }
        puts JSON.generate('data' => { 'node' => node })
      else
        pull = { 'state' => 'OPEN', 'headRefOid' => ENV.fetch('LIVE_HEAD') }
        puts JSON.generate('data' => { 'repository' => { 'pullRequest' => pull } })
      end
    elsif path == 'user' then puts JSON.generate('login' => 'ada')
    elsif path.start_with?('repos/owner/repo/issues/1/labels/')
      log.call("delete \#{path.split('/').last}")
      puts '[]'
    elsif path.start_with?('repos/owner/repo/issues/1/labels')
      puts JSON.generate([{ 'name' => 'awaiting-merge-approval' }])
    elsif path.start_with?('repos/owner/repo/issues/1/comments')
      body = "<!-- shaka:reply:post-implementation-\#{'a' * 7}-0123abcd -->\\n🤖 Checkpoint\\n" \\
             "<!-- shaka:post-implementation \#{'a' * 40} ready -->\\n"
      puts JSON.generate([{ 'id' => 2, 'node_id' => 'N_2', 'user' => { 'login' => 'ada' },
                            'created_at' => '2026-10-02T00:00:00Z', 'body' => body }])
    else abort "unexpected gh request: \#{ARGV.inspect}"
    end
  RUBY

  def test_leaving_the_merge_wait_after_new_commits_minimizes_the_checkpoint
    output, writes = run_attention('b' * 40)

    assert_equal 'minimized', output.dig('stale_checkpoint', 'state')
    assert_equal ['delete awaiting-merge-approval', 'minimize N_2'], writes
  end

  def test_leaving_the_merge_wait_on_the_checked_head_keeps_the_checkpoint
    output, writes = run_attention('a' * 40)

    assert_equal 'current', output.dig('stale_checkpoint', 'state')
    assert_equal ['delete awaiting-merge-approval'], writes
  end

  private

  def run_attention(live)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'gh'), "#!#{RbConfig.ruby}\n#{FAKE_GH}")
      File.chmod(0o755, File.join(dir, 'gh'))
      env = { 'PATH' => "#{dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}", 'HOME' => dir, 'LIVE_HEAD' => live }
      output, error, status = Open3.capture3(env, *SHAKA_COMMAND, 'attention', 'owner/repo', '1', '--state', 'none')
      assert_predicate status, :success?, error
      writes = File.exist?(File.join(dir, 'writes')) ? File.read(File.join(dir, 'writes')).lines(chomp: true) : []
      [JSON.parse(output), writes]
    end
  end
end
