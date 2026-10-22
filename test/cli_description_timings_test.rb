# frozen_string_literal: true

require_relative 'cli_description_decisions_test'
require 'shaka/publication/timeline_steps'

# The published description carries the timings the helper read from the label timeline.
class CliDescriptionTimingsTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes
  include CliDescriptionDecisionsRun

  COMMAND = CliDescriptionDecisionsTest::COMMAND
  ROOT = CliDescriptionDecisionsTest::ROOT
  SUMMARY = 'Timings sit beside usage.'
  HEAD = 'a' * 40

  def test_description_shows_the_timings_read_from_the_label_timeline
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, decisions: [])

        assert_predicate status, :success?, error
        published = File.read(File.join(dir, 'published.md'))
        assert_includes published, '<summary>Timings · 10m between checkpoints ·'
        assert_match(/\| Waiting on a person: answer \| 2026-10-18 08:10 \| [^|]+ \(resumed\) \|/, published)
      end
    end
  end

  def test_description_lists_logged_steps_and_keeps_the_carried_ones
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, decisions: [], env: steps_env(dir))

        assert_predicate status, :success?, error
        published = File.read(File.join(dir, 'published.md'))
        assert_includes published, '**Measured steps:** Validation 13m (1 run) · Local review 58s (1 run)'
        assert_equal 2, Shaka::TimelineSteps.carried(published).size
      end
    end
  end

  def test_description_counts_work_before_the_first_commit_and_validation
    @task_started_at = '2026-10-18T07:00:00Z'
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, decisions: [], env: steps_env(dir))

        assert_predicate status, :success?, error
        published = File.read(File.join(dir, 'published.md'))
        assert_includes published, '**Before first recorded validation:** 1h 5m'
      end
    end
  end

  private

  def description_content
    super.merge('task_started_at' => @task_started_at)
  end

  # This machine logged a review of the pull request's commit.
  def steps_env(dir)
    log = File.join(dir, 'calls.jsonl')
    review = { 'at' => '2026-10-18T08:20:00Z', 'command' => 'review run', 'head' => HEAD, 'provider' => 'openai',
               'exit' => 0, 'duration_ms' => 58_000 }
    File.write(log, "#{JSON.generate(review)}\n")
    commit = { 'oid' => HEAD, 'committedDate' => '2026-10-18T07:50:00Z', 'tree' => { 'oid' => 'b' * 40 } }
    { 'SHAKA_CALL_LOG' => log, 'PR_COMMITS' => JSON.generate([{ 'commit' => commit }]),
      'EXISTING_BODY' => carried_body }
  end

  # An earlier update, from another session, recorded a validation run.
  def carried_body
    step = { 'id' => 'c' * 16, 'command' => 'evidence run', 'check' => 'validate', 'at' => '2026-10-18T08:05:00Z',
             'duration_ms' => 805_000, 'exit' => 0, 'machine' => 'm1' }
    "<!-- shaka:begin -->\n#{Shaka::TimelineSteps.hidden([step])}\n<!-- shaka:end -->\n"
  end

  def fake_gh = DESCRIPTION_GH
end
