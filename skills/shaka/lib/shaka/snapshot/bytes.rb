# frozen_string_literal: true

module Shaka
  class Snapshot
    # Git speaks bytes. Paths and ref names need not be valid UTF-8, while JSON and ordinary
    # string operations insist on it, so this keeps the two apart: the bytes git gave us for
    # the commands we hand back to git, and a rendered form for anything a person reads.
    module Bytes
      module_function

      # Labelled UTF-8 without checking, so a name survives unchanged and nothing raises.
      def text(value) = value.b.force_encoding(Encoding::UTF_8)

      # Trimming runs on the bytes, because whitespace is ASCII and validity is not needed.
      def trimmed(value) = text(value.b.strip)

      def split(value, separator) = value.b.split(separator).map { |entry| text(entry) }

      # `ls-remote` echoes the ref name beside the sha, and that name may not be valid
      # UTF-8, so the first field is taken from the bytes rather than from text.
      def first_field(value) = text(value.b.split(/\s/).first.to_s)

      # What a person or a JSON report sees; only an unrenderable name changes.
      def readable(value) = value.scrub('?')
    end
  end
end
