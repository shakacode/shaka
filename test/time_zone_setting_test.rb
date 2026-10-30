# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'
require 'shaka/configuration/personal_settings'
require 'shaka/publication/timings_details'
require 'shaka/publication_settings'
require 'tmpdir'
require 'yaml'

# PR timings read in the repository's time zone, then the user's, then UTC.
class TimeZoneSettingTest < Minitest::Test
  include RepositoryConfigTestHelpers

  LOS_ANGELES = 'America/Los_Angeles'
  SUMMER = Time.utc(2026, 7, 1, 18, 0)
  WINTER = Time.utc(2026, 12, 1, 18, 0)

  def test_the_repository_setting_defaults_to_utc_and_accepts_a_zone_name
    with_repository { |root| assert_equal 'UTC', Shaka::RepositoryConfig.load(root:).pr_description['time_zone'] }
    with_repository('pr_description' => { 'time_zone' => LOS_ANGELES }) do |root|
      assert_equal LOS_ANGELES, Shaka::RepositoryConfig.load(root:).pr_description['time_zone']
    end
  end

  def test_the_repository_setting_refuses_anything_but_a_known_zone
    ['America/Los_Angels', '../etc/passwd', 'Pacific Time', 'PST8PDT"', '', nil, 8].each do |zone|
      with_repository('pr_description' => { 'time_zone' => zone }) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, 'pr_description.time_zone'
      end
    end
  end

  def test_the_repository_choice_wins_over_the_users
    with_home(LOS_ANGELES) do |home|
      assert_equal 'Asia/Tokyo', resolved('Asia/Tokyo', home)
      assert_equal 'UTC', resolved('UTC', home)
    end
  end

  def test_the_users_choice_applies_when_the_repository_sets_none
    with_home(LOS_ANGELES) { |home| assert_equal LOS_ANGELES, resolved(nil, home) }
  end

  def test_the_default_applies_when_neither_sets_one
    Dir.mktmpdir { |home| assert_equal 'UTC', resolved(nil, home) }
    with_home(nil) { |home| assert_equal 'UTC', resolved(nil, home) }
  end

  def test_an_invalid_user_zone_is_refused_by_name
    with_home('Mars/Olympus') do |home|
      error = assert_raises(Shaka::Error) { resolved(nil, home) }
      assert_includes error.message, Shaka::Configuration::Paths::PERSONAL_SETTINGS
      assert_includes error.message, 'pr_description.time_zone'
    end
  end

  def test_the_users_other_settings_do_not_affect_publication
    Dir.mktmpdir do |home|
      write_personal(home, 'merge' => { 'preference' => 'auto' }, 'pr_description' => { 'time_zone' => LOS_ANGELES })
      assert_equal LOS_ANGELES, resolved(nil, home)
    end
  end

  def test_private_setup_accepts_the_users_zone_but_leaves_it_out_of_the_clone
    with_home(LOS_ANGELES) do |home|
      personal = Shaka::Configuration::PersonalSettings.load(home:)
      assert_empty personal.keys
      assert_nil personal.values.dig('pr_description', 'time_zone')
    end
    with_home('Mars/Olympus') do |home|
      assert_raises(Shaka::Error) { Shaka::Configuration::PersonalSettings.load(home:) }
    end
  end

  def test_timings_show_the_zone_and_follow_daylight_saving
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

  def resolved(configured, home) = Shaka::PublicationSettings.time_zone(configured, home:)

  def with_home(zone)
    Dir.mktmpdir do |home|
      write_personal(home, zone ? { 'pr_description' => { 'time_zone' => zone } } : {})
      yield home
    end
  end

  def write_personal(home, values)
    path = File.join(home, Shaka::Configuration::Paths::PERSONAL_SETTINGS)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, YAML.dump({ 'version' => 1 }.merge(values)))
  end
end
