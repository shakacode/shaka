# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative '../publication/phases'

module Shaka
  module Evidence
    # Lets a fixed command report how long each of its own phases took, so a slow validation run
    # shows which part was slow. `evidence run` names an empty file in SHAKA_PHASE_LOG, and the
    # command may append one JSON line per phase, such as {"phase":"tests","duration_ms":250000}.
    # The command is candidate code and the phases are published, so only the shape `Phases` allows is
    # kept; any other line is skipped.
    module PhaseLog
      VARIABLE = 'SHAKA_PHASE_LOG'
      MAX_BYTES = 64 * 1024

      module_function

      # Yields the file path to hand the command and returns the block's value with the phases read back.
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

      def read(path)
        text = File.open(path, OPEN_FLAGS, binmode: true) { |io| io.stat.file? ? io.read(MAX_BYTES) : nil }
        text = (+text.to_s).force_encoding(Encoding::UTF_8)
        text.valid_encoding? ? sanitize(text.each_line.filter_map { |line| parse(line) }) : {}
      rescue SystemCallError, IOError
        {}
      end

      def parse(line)
        record = JSON.parse(line)
        [record['phase'], record['duration_ms']] if record.is_a?(Hash)
      rescue JSON::ParserError, EncodingError
        nil
      end

      def sanitize(phases) = Phases.sanitize(phases)
    end
  end
end
