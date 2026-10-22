# frozen_string_literal: true

require_relative '../publication/comment_history'

module Shaka
  # Keeps this account's older checkpoint comments linked to its newest execution.
  class PostImplementationHistory < CommentHistory
    MARKER = 'Superseded — read the current checkpoint:'
    KEY = /\A<!-- shaka:reply:post-implementation-[0-9a-f]{7}-[0-9a-f]{8} -->\n/
    SUMMARY = 'Earlier checkpoint'
  end
end
