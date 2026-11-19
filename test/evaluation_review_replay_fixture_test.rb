# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/review_replay'
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
    settings = with_source_alternate { replay.prepare(@criteria) }

    assert_equal @row.fetch('head'), git(@fixture, 'rev-parse', 'HEAD')
    assert_empty git(@fixture, 'remote')
    assert_empty git(@fixture, 'status', '--porcelain')
    assert_equal 'trusted criteria', git(@fixture, 'show', "#{settings}:AGENTS.md")
    refute system('git', '-C', @fixture, 'cat-file', '-e', @fixed, out: File::NULL, err: File::NULL)
  end

  def test_projection_ignores_replacement_refs_for_the_criteria_commit
    replacement = commit(@source, 'AGENTS.md', 'substitute criteria')
    git(@source, 'replace', @criteria, replacement)
    replay = Shaka::Evaluation::ReviewReplayFixture.new(source: @source, root: @fixture, row: @row)

    settings = replay.prepare(@criteria)

    assert_equal 'trusted criteria', git(@fixture, 'show', "#{settings}:AGENTS.md")
  end

  def test_projection_refuses_symlinks_at_the_settings_directory_boundary
    File.symlink('unavailable', File.join(@source, '.agents'))
    git(@source, 'add', '.agents')
    revision = commit(@source, 'AGENTS.md', 'linked settings')

    error = assert_raises(IOError) { Shaka::Evaluation::ReviewReplayFixture.entries(@source, revision) }
    assert_match(/Use regular files/, error.message)
  end

  def test_failed_reviewer_retains_its_bytes_and_session_while_the_budget_stays_pending
    replay = failing_replay
    error = assert_raises(IOError) { replay.run([@row.merge('id' => 'r01')]) }
    assert_match(/reconcile budget reservation/, error.message)
    assert_failed_record
  end

  private

  def assert_failed_record
    records = Dir.glob(File.join(@directory, '*.json'))
    assert_equal 1, records.size
    result = JSON.parse(File.read(records.fetch(0))).fetch('result')
    assert_equal [255], result.dig('invalid_output', 'base64').unpack1('m0').bytes
    assert_equal 'fake session', File.read(result.fetch('native_sessions').fetch(0))
  end

  def failing_replay
    options = { source: @source, directory: @directory, reviewer: 'openai/codex', helper: failing_helper,
                baseline: { criteria: @criteria, model: 'one' }, candidate: { criteria: @criteria, model: 'two' },
                budget: File.join(@directory, 'budget'), scope: '1', cap: 5,
                limits: { 'monthly' => 200, 'pr' => 15, 'nightly' => 5 } }
    Shaka::Evaluation::ReviewReplay.new(options).tap do |replay|
      replay.define_singleton_method(:verify_login) { @environment['CODEX_HOME'] = File.join(@scratch, 'codex') }
    end
  end

  def failing_helper
    path = File.join(@directory, 'stub-reviewer')
    File.write(path, <<~SH, perm: 0o700)
      #!/bin/sh
      mkdir -p "$CODEX_HOME/sessions"
      printf 'fake session' > "$CODEX_HOME/sessions/failure.jsonl"
      printf '\\377'
      exit 1
    SH
    path
  end

  def with_source_alternate
    key = 'GIT_ALTERNATE_OBJECT_DIRECTORIES'
    previous = ENV.fetch(key, nil)
    ENV[key] = File.join(@source, '.git', 'objects')
    yield
  ensure
    ENV[key] = previous
  end

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
