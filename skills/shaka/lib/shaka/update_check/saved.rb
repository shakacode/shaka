# frozen_string_literal: true

require_relative 'cache'

module Shaka
  class UpdateCheck
    # A registered checkout's answers between calls, so GitHub is asked at most once a day for each
    # installed commit and record; Cache decides which answers count.
    module Saved
      # Later helper calls repeat a registered checkout's answer from this cache instead of the network.
      def remember(result)
        Cache.record(@checkout, result, installed: installed(@head, @compared), home:) if @checkout
      end

      private

      def saved(head) = (Cache.reuse(@checkout, installed: installed(head, @target), home:) if @checkout)

      # What a saved answer describes: the checkout's HEAD commit, the revision its record names, and the
      # repository and branch GitHub compared. Only an answer from GitHub names that last part, so an
      # answer worked out locally is never repeated in place of a GitHub comparison.
      def installed(head, compared) = { 'commit' => head, 'revision' => @source['revision'], 'compared' => compared }

      def home = Dir.home
    end
  end
end
