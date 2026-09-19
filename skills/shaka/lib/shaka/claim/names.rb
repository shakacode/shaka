# frozen_string_literal: true

module Shaka
  class Claim
    # Compiles a repository branch-name template into a matcher for remote heads.
    class Names
      DEFAULT = '{login}-{host}/{issue}-{description}'
      WILDCARDS = { 'login' => '[^/]+', 'host' => '[^/]+', 'description' => '.+' }.freeze

      def initialize(query:, template:)
        @query = query
        @template = template
      end

      def reported = @template || DEFAULT

      def cover?(name)
        name.match?(issue_token_pattern) || template_match?(name)
      end

      private

      def issue_token_pattern = %r{(?:^|/)#{Regexp.escape(@query)}-}

      def template_match?(name)
        return false if @template.nil? || @template.strip.empty?

        name.match?(template_pattern)
      end

      def template_pattern
        @template_pattern ||= begin
          pieces = @template.split(/\{(login|host|issue|description)\}/)
          regex = pieces.each_with_index.map { |piece, index| index.even? ? Regexp.escape(piece) : token_regex(piece) }
          Regexp.new("\\A#{regex.join}\\z")
        end
      end

      def token_regex(token)
        token == 'issue' ? Regexp.escape(@query) : WILDCARDS.fetch(token)
      end
    end
  end
end
