# frozen_string_literal: true

module Shaka
  # Shares the publication markers and their read boundary across description consumers.
  module Publishing
    OPEN_MARK = '<!-- shaka:begin -->'
    CLOSE_MARK = '<!-- shaka:end -->'

    # Only text between one opening and one later closing marker is the helper's own.
    def self.managed_region(body)
      text = body.to_s
      return unless text.scan(OPEN_MARK).one? && text.scan(CLOSE_MARK).one?

      open = text.index(OPEN_MARK)
      close = text.index(CLOSE_MARK)
      text[(open + OPEN_MARK.length)...close] if open < close
    end
  end
end
