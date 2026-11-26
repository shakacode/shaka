# frozen_string_literal: true

require_relative '../error'
require_relative 'publisher'

module Shaka
  module UiCheck
    # Gives the description its Screenshots link: the PR's current UI check comment, read from
    # GitHub so the content file can neither supply nor keep one.
    module Link
      KEY = 'ui_check'

      module_function

      # A PR without a UI check renders as it did before this link existed. So does one whose
      # comments cannot be read: the link is a convenience, never a reason to refuse a description.
      def resolve(content, github)
        url = Publisher.new(github).current&.fetch('html_url', nil)
        url ? content.merge(KEY => url) : content.except(KEY)
      rescue Error
        content.except(KEY)
      end
    end
  end
end
