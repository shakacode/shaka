# frozen_string_literal: true

module Shaka
  module PublicComments
    # Refuses shell commands that would print issue, review, or inline comment bodies.
    class FetchGuard
      CLIENT = /\b(?:gh|curl|wget)\b/
      ENDPOINT = %r{
        (?:https://api\.github\.com)?/?repos/[^/\s"'`]+/[^/\s"'`]+/
        (?:issues/(?:comments/\d+|\d+/comments)
          |pulls/(?:comments/\d+|\d+/(?:comments|reviews)(?:/\d+(?:/comments)?)?))
        (?=$|[\s"'`?&#])
      }x
      VIEW = /\bgh\s+(?:pr|issue)\s+view\b/
      COMMENTS_FLAG = /(?:^|\s)--comments(?:\s|=|$)/
      JSON_FIELDS = %w[comments reviews].freeze
      GRAPHQL_TARGET = /\b(?:comments|reviews|reviewThreads|reviewThread)\b/
      BODY = /\bbody\b/
      INLINE_QUERY = /(?:-f|--raw-field)\s+query=(['"])(.*?)\1/m

      def self.denied?(command) = new(command.to_s).denied?

      def self.denial
        {
          'permission' => 'deny',
          'user_message' => 'Blocked a read of GitHub comment or review text.',
          'agent_message' => 'This command would load issue, review, or inline comment bodies. ' \
                             'Use `shaka comments` so excluded bodies stay withheld.'
        }
      end

      def initialize(command)
        @command = command
      end

      def denied?
        return false unless @command.match?(CLIENT)

        endpoint? || listed_view? || graphql_body?
      end

      private

      def endpoint? = @command.match?(ENDPOINT)

      def listed_view?
        return false unless @command.match?(VIEW)

        @command.match?(COMMENTS_FLAG) || json_fields.intersect?(JSON_FIELDS)
      end

      def json_fields
        @command.scan(/--json(?:=|\s+)(\S+)/).flat_map { |match| match.fetch(0).split(',') }
      end

      def graphql_body?
        return false unless tokens_after('gh', 'api').include?('graphql')

        query = inline_query
        query.nil? || (query.match?(GRAPHQL_TARGET) && query.match?(BODY))
      end

      def tokens_after(*names)
        tokens = @command.scan(/\S+/)
        names.each do |name|
          index = tokens.index { |token| token == name || token.end_with?("/#{name}") }
          return [] unless index

          tokens = tokens[(index + 1)..]
        end
        tokens
      end

      def inline_query
        match = @command.match(INLINE_QUERY)
        match&.[](2)
      end
    end
  end
end
