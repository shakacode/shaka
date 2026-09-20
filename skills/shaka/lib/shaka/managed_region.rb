# frozen_string_literal: true

require_relative 'error'

module Shaka
  # The description region this workflow owns inside a pull request body. A body holds
  # exactly one well-ordered marker pair or none at all. Anything else was edited into a
  # shape this workflow cannot have written, and is neither published into nor read for
  # comparison. Both callers ask this one object so the two answers cannot disagree.
  class ManagedRegion
    OPEN = '<!-- shaka:begin -->'
    CLOSE = '<!-- shaka:end -->'
    TEXT = /#{Regexp.escape(OPEN)}(.*?)#{Regexp.escape(CLOSE)}/m
    AMBIGUOUS = 'The description has an ambiguous or malformed managed region; repair it before publishing.'

    def initialize(body)
      @body = body.to_s
    end

    # Prose mentioning a marker's name is not a marker; only the complete text counts.
    def absent? = !(@body.include?(OPEN) || @body.include?(CLOSE))

    # What follows the opening marker is taken as written, so a body whose line endings
    # changed still reads as the region a passing check said it is.
    def text
      return if absent?

      check
      @body[TEXT, 1]
    end

    def check
      return if one_pair?

      raise Error, AMBIGUOUS
    end

    private

    def one_pair?
      @body.scan(OPEN).size == 1 && @body.scan(CLOSE).size == 1 && @body.index(OPEN) < @body.index(CLOSE)
    end
  end
end
