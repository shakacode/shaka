# frozen_string_literal: true

require_relative 'cli_description_decisions_test'
require 'shaka/publication/time_zone'

# The published Timings section follows the repository's time zone, then the user's.
class CliDescriptionTimeZoneTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes
  include CliDescriptionDecisionsRun

  COMMAND = CliDescriptionDecisionsTest::COMMAND
  ROOT = CliDescriptionDecisionsTest::ROOT
  SUMMARY = 'Timings read in the chosen zone.'

  def test_description_shows_the_users_time_zone_when_the_repository_sets_none
    skip 'this machine has no zone data' unless File.directory?(Shaka::TimeZone.database)

    published = publish(user_zone: 'America/Los_Angeles')
    assert_includes published, 'Times are America/Los_Angeles wall-clock time.'
    assert_match(/\| Waiting on a person: answer \| 2026-10-18 01:10 \|/, published)
  end

  def test_description_prefers_the_repository_time_zone_to_the_users
    skip 'this machine has no zone data' unless File.directory?(Shaka::TimeZone.database)

    published = publish(user_zone: 'America/Los_Angeles',
                        settings: { 'pr_description' => { 'time_zone' => 'Asia/Tokyo' } })
    assert_includes published, 'Times are Asia/Tokyo wall-clock time.'
    assert_match(/\| Waiting on a person: answer \| 2026-10-18 17:10 \|/, published)
  end

  def test_description_still_publishes_in_utc_when_the_users_time_zone_is_unusable
    assert_includes publish(user_zone: 'Pacific Time'), 'Times are UTC wall-clock time.'
  end

  private

  def publish(user_zone:, settings: {})
    with_repository(settings) do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        write_user_zone(dir, user_zone)
        _output, error, status = run_description(dir, root:, decisions: [])
        assert_predicate status, :success?, error
        return File.read(File.join(dir, 'published.md'))
      end
    end
  end

  def write_user_zone(home, zone)
    path = File.join(home, '.agents/shaka/config.yml')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, YAML.dump('version' => 1, 'pr_description' => { 'time_zone' => zone }))
  end

  def fake_gh = DESCRIPTION_GH
end
