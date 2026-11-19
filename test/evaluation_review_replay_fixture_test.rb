# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/review_replay_fixture'

class EvaluationReviewReplayFixtureTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @source = File.join(@directory, 'source')
    @fixture = File.join(@directory, 'fixture')
    Dir.mkdir(@source)
    Dir.mkdir(@fixture)
    git(@source, 'init', '--quiet', '--template=')
    seed_history
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_historical_fixture_excludes_future_objects_and_copies_review_settings
    replay = Shaka::Evaluation::ReviewReplayFixture.new(source: @source, root: @fixture, row: @row)
    settings = replay.prepare(@criteria)

    assert_equal @row.fetch('head'), git(@fixture, 'rev-parse', 'HEAD')
    assert_empty git(@fixture, 'remote')
    assert_empty git(@fixture, 'status', '--porcelain')
    assert_equal 'trusted criteria', git(@fixture, 'show', "#{settings}:AGENTS.md")
    refute system('git', '-C', @fixture, 'cat-file', '-e', @fixed, out: File::NULL, err: File::NULL)
  end

  private

  def seed_history
    @row = { 'base' => commit(@source, 'subject.rb', 'before'),
             'head' => commit(@source, 'subject.rb', 'under review') }
    @fixed = commit(@source, 'subject.rb', 'fixed')
    @criteria = commit(@source, 'AGENTS.md', 'trusted criteria')
  end

  def commit(root, path, content)
    File.write(File.join(root, path), content)
    git(root, 'add', path)
    git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--quiet', '-m', content)
    git(root, 'rev-parse', 'HEAD')
  end

  def git(root, *args)
    output, status = Open3.capture2('git', '-C', root, *args)
    raise "git #{args.join(' ')} failed" unless status.success?

    output.strip
  end
end
