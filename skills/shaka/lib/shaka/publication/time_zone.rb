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

    # A machine without a zone database cannot judge a name, and it renders in UTC anyway.
    def validate!(value, label)
      return if value == UTC || (well_formed?(value) && (known?(value) || !File.directory?(database)))

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
    def known?(name) = File.file?(File.join(database, name))
    def database = ENV.fetch('TZDIR', '/usr/share/zoneinfo')
  end
end
