# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'
require 'shaka/configure_settings'
require 'tmpdir'
require 'yaml'

# PR timings read in the repository's time zone, then the user's, then UTC.
class TimeZoneSettingTest < Minitest::Test
  include RepositoryConfigTestHelpers

  LOS_ANGELES = 'America/Los_Angeles'

  def test_the_repository_setting_defaults_to_utc_and_accepts_a_zone_name
    with_repository { |root| assert_equal 'UTC', Shaka::RepositoryConfig.load(root:).pr_description['time_zone'] }
    with_repository('pr_description' => { 'time_zone' => LOS_ANGELES }) do |root|
      assert_equal LOS_ANGELES, Shaka::RepositoryConfig.load(root:).pr_description['time_zone']
    end
  end

  def test_the_repository_setting_refuses_anything_shaped_unlike_a_zone_name
    ['../etc/passwd', 'Pacific Time', 'PST8PDT"', '', nil, 8].each do |zone|
      with_repository('pr_description' => { 'time_zone' => zone }) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, 'pr_description.time_zone'
      end
    end
  end

  def test_a_repository_zone_this_machine_lacks_does_not_stop_shaka
    with_repository('pr_description' => { 'time_zone' => 'America/Los_Angels' }) do |root|
      assert_equal 'America/Los_Angels', Shaka::RepositoryConfig.load(root:).time_zone(home: nil)
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

  def test_a_broken_personal_file_counts_as_no_choice
    ['not: [valid', "review: {}\n", "- a list\n"].each do |content|
      Dir.mktmpdir do |home|
        write_personal(home, {})
        File.write(File.join(home, Shaka::Configuration::Paths::PERSONAL_SETTINGS), content)
        assert_equal 'UTC', resolved(nil, home)
      end
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
    with_home('Pacific Time') do |home|
      error = assert_raises(Shaka::Error) { Shaka::Configuration::PersonalSettings.load(home:) }
      assert_includes error.message, 'pr_description.time_zone'
    end
  end

  def test_the_settings_report_shows_the_zone_that_applies
    skip 'this machine has no zone data' unless File.directory?(Shaka::TimeZone.database)

    with_repository do |root|
      with_home(LOS_ANGELES) { |home| assert_equal LOS_ANGELES, report_row(root, home) }
    end
    with_repository('pr_description' => { 'time_zone' => 'America/Los_Angels' }) do |root|
      Dir.mktmpdir { |home| assert_equal 'UTC', report_row(root, home) }
    end
  end

  private

  def resolved(configured, home)
    settings = configured ? { 'pr_description' => { 'time_zone' => configured } } : {}
    with_repository(settings) { |root| Shaka::RepositoryConfig.load(root:).time_zone(home:) }
  end

  def report_row(root, home)
    original = Dir.home
    ENV['HOME'] = home
    context = Shaka::ConfigureSettings::Context.new(config: Shaka::RepositoryConfig.load(root:), raw: {}, root:)
    Shaka::ConfigureSettings::SETTINGS.find { it.key == 'pr_description.time_zone' }.resolve.call(context)
  ensure
    ENV['HOME'] = original
  end

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
