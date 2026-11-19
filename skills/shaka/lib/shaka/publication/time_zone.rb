# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Shows stored UTC instants in a named zone. Ruby's Time takes a zone name only through TZ, where
  # an unknown name silently means UTC, so a name is checked against the zone database first.
  module TimeZone
    UTC = 'UTC'
    NAME = %r{\A[A-Za-z0-9_+-]+(?:/[A-Za-z0-9_+-]+)*\z}
    SWITCH = Mutex.new

    module_function

    # A repository's name only has to be well formed: machines hold different zone data, and one
    # missing a zone shows UTC rather than failing every command that reads the settings.
    def well_formed!(value, label)
      raise Error, "#{label} must be a time zone name such as America/Los_Angeles" unless well_formed?(value)
    end

    # Setup checks the user's own file against this machine, unless it has no zone data to judge by.
    def validate!(value, label)
      well_formed!(value, label)
      return if value == UTC || known?(value) || !File.directory?(database)

      raise Error, "#{label} must be a time zone name such as America/Los_Angeles"
    end

    # What this machine can render: anything else is shown, and labeled, as UTC.
    def renderable(name) = well_formed?(name) && known?(name) ? name : UTC

    def strftime(time, zone, pattern)
      return time.getutc.strftime(pattern) if zone == UTC

      SWITCH.synchronize do
        saved = ENV.fetch('TZ', nil)
        ENV['TZ'] = zone
        time.getlocal.strftime(pattern)
      ensure
        ENV['TZ'] = saved
      end
    end

    def well_formed?(value) = value.is_a?(String) && value.match?(NAME)

    # The database also holds text files, which TZ would silently read as UTC.
    def known?(name)
      File.binread(File.join(database, name), 4) == 'TZif'
    rescue SystemCallError
      false
    end

    def database = ENV.fetch('TZDIR', '/usr/share/zoneinfo')
  end
end
