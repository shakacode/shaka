# frozen_string_literal: true

module Shaka
  # Shares the publication markers and their read boundary across description consumers.
  module Publishing
    OPEN_MARK = '<!-- shaka:begin -->'
    CLOSE_MARK = '<!-- shaka:end -->'
    # Older writers reject the extra opener instead of overwriting accounting they cannot read.
    ARCHIVE_GUARD = "#{CLOSE_MARK}\n<!-- shaka:usage-archive:v1 -->\n#{OPEN_MARK}".freeze

    def self.without_archive_guard(body) = body.sub(ARCHIVE_GUARD, CLOSE_MARK)
    def self.with_archive_guard(body) = body.sub(CLOSE_MARK, ARCHIVE_GUARD)

    # Only text between one opening and one later closing marker is the helper's own.
    def self.managed_region(body)
      text = without_archive_guard(body.to_s)
      return unless text.scan(OPEN_MARK).one? && text.scan(CLOSE_MARK).one?

      open = text.index(OPEN_MARK)
      close = text.index(CLOSE_MARK)
      text[(open + OPEN_MARK.length)...close] if open < close
    end
  end
end
