# frozen_string_literal: true

require_relative '../public_comments/bounded_list'
require_relative 'references'

module Shaka
  class Claim
    # Search discovers candidates; comment prose stays internal reference data, never CLI output.
    class Comments
      # Adapts the existing bounded REST pager to claim command capture.
      class Lists
        def initialize(capture) = @capture = capture

        def api_list(path)
          rows = JSON.parse(@capture.call(['gh', 'api', path]))
          raise Error, 'GitHub claim comment list must be an array.' unless rows.is_a?(Array)

          rows
        rescue JSON::ParserError
          raise Error, 'GitHub returned invalid comment JSON.'
        end
      end

      def initialize(query:, capture:)
        @query = query
        @lists = Lists.new(capture)
      end

      def cover?(pull_request)
        references = References.new(query: @query, pull_request: pull_request)
        paths(pull_request).any? do |path|
          pager = PublicComments::BoundedList.new(@lists, max_pages: 10, label: 'GitHub claim comment list')
          comments = pager.call(path)
          comments.any? { |comment| references.reference?(body(comment)) }
        end
      end

      private

      def paths(pull_request)
        repository = pull_request.fetch('url').sub(%r{/pull/\d+\z}, '').split('/').last(2).join('/')
        prefix = "repos/#{repository}"
        number = pull_request.fetch('number')
        ["#{prefix}/issues/#{number}/comments", "#{prefix}/pulls/#{number}/comments",
         "#{prefix}/pulls/#{number}/reviews"]
      end

      def body(comment)
        value = comment['body']
        return value.to_s if comment.key?('body') && (value.nil? || value.is_a?(String))

        raise Error, 'GitHub returned incomplete comment metadata.'
      end
    end
  end
end
