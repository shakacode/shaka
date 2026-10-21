# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require_relative '../update_check/cache'

module Shaka
  class StartupNotice
    # Small files outside every repository: when doctor last ran on this machine, and when each
    # reminder last showed, so a reminder appears at most once a day.
    module Marks
      module_function

      def directory(home) = File.join(home, '.local', 'share', 'shaka')

      def doctor_path(home) = File.join(directory(home), 'doctor-ran')

      def notices_path(home) = File.join(directory(home), 'notices.json')

      # Nothing reads the mark while notices are off, so doctor then writes nothing.
      def doctor_ran(env: ENV, home: Dir.home, now: Time.now)
        return if env[VARIABLE] == 'off'

        write(doctor_path(home), "#{now.utc.iso8601}\n")
      rescue SystemCallError => e
        warn "shaka: doctor run not recorded: #{e.message}"
      end

      def doctor_ran?(home) = File.file?(doctor_path(home))

      def shown_today?(key, home:, now:) = UpdateCheck::Cache.fresh?(shown(home)[key], now)

      # False when the time cannot be saved: a reminder that cannot be limited to once a day is not shown.
      def show(key, home:, now:)
        write(notices_path(home), "#{JSON.generate(shown(home).merge(key => now.utc.iso8601))}\n")
        true
      rescue SystemCallError
        false
      end

      def shown(home)
        entry = JSON.parse(File.read(notices_path(home)))
        entry.is_a?(Hash) ? entry : {}
      rescue SystemCallError, JSON::ParserError
        {}
      end

      def write(target, text)
        FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
        temporary = "#{target}.#{Process.pid}"
        File.write(temporary, text, perm: 0o600)
        File.rename(temporary, target)
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end
    end
  end
end
