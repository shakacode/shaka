# frozen_string_literal: true

require_relative '../error'
require_relative '../publication/links'
require_relative 'publisher'

module Shaka
  module UiCheck
    # Gives the description its Screenshots link: the PR's current UI check comment, read from
    # GitHub so the content file can neither supply nor keep one.
    module Link
      KEY = 'ui_check'

      module_function

      # A PR without a UI check renders as it did before this link existed. So does one whose
      # comments cannot be read, or whose check has a URL the renderer would refuse: the link is
      # a convenience, never a reason to refuse a description. A failed read says so on stderr.
      def resolve(content, github, warn: Kernel.method(:warn))
        url = Publisher.new(github).current&.fetch('html_url', nil)
        usable = url.is_a?(String) && url.match?(PublicationLinks::REVIEW_URL)
        usable ? content.merge(KEY => url) : content.except(KEY)
      rescue Error => e
        warn.call("shaka: Screenshots link omitted; UI checks could not be read: #{e.message}")
        content.except(KEY)
      end
    end
  end
end
