# frozen_string_literal: true

require_relative 'cache'

module Shaka
  class UpdateCheck
    # A registered checkout's answers between calls, so GitHub is asked at most once a day for each
    # installed commit and record; Cache decides which answers count.
    module Saved
      # Later helper calls repeat a registered checkout's answer from this cache instead of the network.
      def remember(result) = (Cache.record(@checkout, result, installed: installed(@head), home:) if @checkout)

      private

      def saved(head) = (Cache.reuse(@checkout, installed: installed(head), home:) if @checkout)

      # What a saved answer describes: the checkout's HEAD commit and the revision its record names.
      def installed(head) = { 'commit' => head, 'revision' => @source['revision'] }

      def home = Dir.home
    end
  end
end
