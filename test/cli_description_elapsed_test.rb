# frozen_string_literal: true

require_relative 'cli_description_decisions_test'
require_relative 'publication_test'

# With no supplied start and no running watch, a description update still works out the time to ready.
class CliDescriptionElapsedTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes
  include CliDescriptionDecisionsRun

  COMMAND = CliDescriptionDecisionsTest::COMMAND
  ROOT = CliDescriptionDecisionsTest::ROOT
  SUMMARY = 'The time to ready shows without a watch.'
  CHECKS = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass', 'completedAt' => '2026-10-18T08:10:00Z' },
            { 'name' => 'claude-review', 'state' => 'SUCCESS', 'bucket' => 'pass',
              'completedAt' => '2026-10-18T08:30:00Z' }].freeze

  def test_the_usage_report_and_green_checks_supply_the_time_to_ready
    assert_includes published('PR_CHECKS' => JSON.generate(CHECKS)), '· ready in 1h 30m'
  end

  def test_an_unreadable_check_list_still_publishes
    refute_includes published, '· ready in'
  end

  def description_content
    record = USAGE_RECORD.merge('from' => '2026-10-18T07:00:00Z', 'covers_task' => true,
                                'columns' => [PublicationRegressionTest::USAGE_COLUMN])
    super.merge('usage' => { 'note' => 'Native usage is PARTIAL.', 'records' => [record] })
  end

  private

  def published(env = {})
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, decisions: [], env:)
        assert_predicate status, :success?, error
        return File.read(File.join(dir, 'published.md'))
      end
    end
  end

  def fake_gh = DESCRIPTION_GH
end
