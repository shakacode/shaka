# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require_relative '../install/locations'

module Shaka
  class UpdateCheck
    # The last update-check answer for one registered checkout, kept so later helper calls can
    # repeat it without a network request. One file serves the machine; it names its checkout.
    module Cache
      SECONDS = 24 * 60 * 60
      # An hour under the notice's day, so a check scheduled at the same time each day still asks GitHub.
      REUSE_SECONDS = SECONDS - (60 * 60)

      module_function

      # The real path, so a checkout reached through a link or /var on macOS keeps one entry.
      def key(checkout) = File.realpath(checkout)

      def path(home) = File.join(home, '.local', 'share', 'shaka', 'update-check.json')

      # The entry for this checkout, or an empty one when the file is missing, unreadable, or another checkout's.
      def read(checkout, home:)
        entry = JSON.parse(File.read(path(home)))
        entry.is_a?(Hash) && entry['checkout'] == key(checkout) ? entry : {}
      rescue SystemCallError, JSON::ParserError
        {}
      end

      # Names what the answer describes, `installed`: the HEAD `commit`, the record's `revision`, and what
      # GitHub `compared`. Keeps the last notice time, so a new answer does not repeat a notice shown today.
      # A failed check is not saved, so a check that keeps failing still earns the daily reminder, and
      # neither is a repeated answer, which carries its `checked_at`, so it still expires a day after
      # GitHub gave it.
      def record(checkout, result, installed:, home: nil, now: Time.now)
        return if result['status'] == 'unknown' || result.key?('checked_at')

        home ||= Dir.home
        noticed = read(checkout, home:).slice('noticed_at')
        write(home, { 'checkout' => key(checkout), **installed, 'checked_at' => now.utc.iso8601, 'result' => result,
                      **noticed })
      rescue SystemCallError, ArgumentError => e
        warn "Shaka update check not cached: #{e.message}"
      end

      # The saved result with its check time, while it is under REUSE_SECONDS old and describes the same
      # commit, revision, and comparison. install --update can change the first two.
      def reuse(checkout, installed:, home:, now: Time.now)
        entry = read(checkout, home:)
        return unless installed.values.all? && entry['result'].is_a?(Hash) && entry.slice(*installed.keys) == installed

        entry['result'].merge('checked_at' => entry['checked_at']) if fresh?(entry['checked_at'], now, REUSE_SECONDS)
      end

      # Whether the entry describes the revision the checkout's installation record names now. Read from
      # the record file, because the startup notice runs no command.
      def current?(entry, checkout)
        record = JSON.parse(File.read(File.join(checkout, '.git', Install::Locations::RECORD)))
        revision = record.dig('identity', 'source', 'revision') if record.is_a?(Hash)
        !revision.nil? && entry['revision'] == revision
      rescue SystemCallError, JSON::ParserError, TypeError
        false
      end

      # False when the time cannot be saved: a notice that cannot be limited to once a day is not shown.
      def noticed(entry, checkout, home:, now: Time.now)
        write(home, entry.merge('checkout' => key(checkout), 'noticed_at' => now.utc.iso8601))
        true
      rescue SystemCallError
        false
      end

      # A time ahead of the clock, as after a clock change, is stale rather than fresh until the clock catches up.
      def fresh?(time, now, seconds = SECONDS)
        (0...seconds).cover?(now - Time.iso8601(time.to_s))
      rescue ArgumentError
        false
      end

      def write(home, entry)
        target = path(home)
        FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
        temporary = "#{target}.#{Process.pid}"
        File.write(temporary, "#{JSON.generate(entry)}\n", perm: 0o600)
        File.rename(temporary, target)
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end
    end
  end
end
