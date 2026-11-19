# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative '../publication/failed_tests'
require_relative '../publication/phases'

module Shaka
  module Evidence
    # Lets a fixed command report how long each of its own phases took, so a slow validation run
    # shows which part was slow. `evidence run` names an empty file in SHAKA_PHASE_LOG, and the
    # command may append one JSON line per phase, such as {"phase":"tests","duration_ms":250000}, and
    # a line naming the test classes that failed, such as {"failed_tests":["SettingsTest"]}. The command
    # is candidate code and both are published, so only the shapes `Phases` and `FailedTests` allow are
    # kept; any other line is skipped.
    module PhaseLog
      VARIABLE = 'SHAKA_PHASE_LOG'
      MAX_BYTES = 64 * 1024

      module_function

      # Yields the file path to hand the command and returns the block's value with what the command reported.
      def with_file
        Dir.mktmpdir('shaka-phases') do |directory|
          path = File.join(directory, 'phases.jsonl')
          File.write(path, '', perm: 0o600)
          value = yield path
          [value, read(path)]
        end
      end

      # Opens without waiting and reads only a regular file, so a command that swaps the file for a pipe,
      # a device, or a link cannot stall the helper or point it elsewhere.
      OPEN_FLAGS = %i[NONBLOCK NOFOLLOW].sum(File::RDONLY) { |flag| File.const_defined?(flag) ? File.const_get(flag) : 0 }

      # {"phases" => {...}, "failed_tests" => [...]}, leaving out what the command did not report.
      def read(path)
        text = File.open(path, OPEN_FLAGS, binmode: true) { |io| io.stat.file? ? io.read(MAX_BYTES) : nil }
        text = (+text.to_s).force_encoding(Encoding::UTF_8)
        text.valid_encoding? ? report(text.each_line.filter_map { |line| parse(line) }) : {}
      rescue SystemCallError, IOError
        {}
      end

      def parse(line)
        record = JSON.parse(line)
        record if record.is_a?(Hash)
      rescue JSON::ParserError, EncodingError
        nil
      end

      def report(records)
        phases = records.filter_map { |record| record.values_at('phase', 'duration_ms') if record.key?('phase') }
        failed = records.flat_map { |record| record['failed_tests'].is_a?(Array) ? record['failed_tests'] : [] }
        { 'phases' => Phases.sanitize(phases), 'failed_tests' => FailedTests.sanitize(failed) }
          .reject { |_key, value| value.empty? }
      end
    end
  end
end
