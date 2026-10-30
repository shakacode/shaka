# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/timings_details'
require 'tmpdir'

# Timings convert UTC instants for display only, and never claim a zone they could not apply.
class TimeZoneRenderingTest < Minitest::Test
  LOS_ANGELES = 'America/Los_Angeles'
  SUMMER = Time.utc(2026, 7, 1, 18, 0)
  WINTER = Time.utc(2026, 12, 1, 18, 0)

  def test_timings_show_the_zone_and_follow_daylight_saving
    skip 'this machine has no zone data' unless File.directory?(Shaka::TimeZone.database)

    body = timings(LOS_ANGELES)
    assert_includes body, 'Times are America/Los_Angeles wall-clock time.'
    assert_includes body, '2026-07-01 11:00'
    assert_includes body, 'Task start (agent-reported): 2026-07-01 11:00 PDT.'
    assert_includes body, 'Validation started: 2026-12-01 10:00 PST.'
    refute_includes body, 'UTC'
  end

  def test_timings_stay_in_utc_by_default
    body = timings(nil)
    assert_includes body, 'Times are UTC wall-clock time.'
    assert_includes body, 'Task start (agent-reported): 2026-07-01 18:00 UTC.'
  end

  def test_a_zone_this_machine_cannot_resolve_is_labeled_utc_rather_than_mislabeled
    body = timings('Mars/Olympus')
    assert_includes body, 'Times are UTC wall-clock time.'
    assert_includes body, '2026-07-01 18:00 UTC'
    refute_includes body, 'Mars'
  end

  def test_a_file_in_the_zone_database_that_holds_no_zone_is_not_a_zone
    Dir.mktmpdir do |database|
      File.write(File.join(database, 'leapseconds'), "# text, not zone data\n")
      File.binwrite(File.join(database, 'Real'), "TZif#{'x' * 40}")
      with_zone_database(database) do
        assert_equal 'UTC', Shaka::TimeZone.renderable('leapseconds')
        assert_equal 'Real', Shaka::TimeZone.renderable('Real')
        assert_raises(Shaka::Error) { Shaka::TimeZone.validate!('leapseconds', 'zone') }
      end
    end
  end

  def test_a_machine_without_zone_data_accepts_the_users_name_and_shows_utc
    with_zone_database('/nonexistent/zoneinfo') do
      assert_nil Shaka::TimeZone.validate!(LOS_ANGELES, 'zone')
      assert_equal 'UTC', Shaka::TimeZone.renderable(LOS_ANGELES)
    end
  end

  def test_the_stored_times_stay_utc_and_the_process_zone_is_restored
    assert_includes timings(LOS_ANGELES), '"task_started_at":"2026-07-01T18:00:00Z"'
    original = ENV.fetch('TZ', nil)
    ENV['TZ'] = 'Asia/Tokyo'
    timings(LOS_ANGELES)
    assert_equal 'Asia/Tokyo', ENV.fetch('TZ', nil)
  ensure
    ENV['TZ'] = original
  end

  private

  def timings(zone)
    timeline = { 'opened' => WINTER + 60, 'first_commit' => SUMMER, 'labels' => [],
                 'task_started_at' => SUMMER, 'first_validation_at' => WINTER }
    Shaka::TimingsDetails.new(timeline, now: WINTER + 120, time_zone: zone).detail['body']
  end

  def with_zone_database(path)
    original = ENV.fetch('TZDIR', nil)
    ENV['TZDIR'] = path
    yield
  ensure
    ENV['TZDIR'] = original
  end
end
