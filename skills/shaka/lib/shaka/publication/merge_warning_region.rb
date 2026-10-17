# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Keeps the checkpoint warning ahead of a newly inserted feature description.
  module MergeWarningRegion
    OPEN = '<!-- shaka:merge-warning:begin -->'
    CLOSE = '<!-- shaka:merge-warning:end -->'

    module_function

    def prepend(existing, managed)
      warning, remaining = split(existing)
      "#{warning}#{managed}\n\n#{remaining}"
    end

    def remove(body) = split(body).last

    # The commit the warning links, or nil when the region has no generated head link.
    def head(body) = split(body).first[%r{/commit/(\h{40})\)}, 1]

    def split(body)
      return ['', body] if body.scan(OPEN).empty? && body.scan(CLOSE).empty?

      validate(body)
      prefix, rest = body.split(OPEN, 2)
      warning, suffix = rest.split(CLOSE, 2)
      ["#{OPEN}#{warning}#{CLOSE}\n\n", "#{prefix}#{suffix.delete_prefix("\n\n")}"]
    end

    def validate(body)
      return if body.scan(OPEN).one? && body.scan(CLOSE).one? && body.index(OPEN) < body.index(CLOSE)

      raise Error, 'Merge warning markers are ambiguous or malformed; repair them before retrying.'
    end
  end
end
