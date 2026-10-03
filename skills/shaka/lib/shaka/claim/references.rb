# frozen_string_literal: true

module Shaka
  class Claim
    # A reference is collision evidence, not proof that the PR owns the work item.
    class References
      TOKENS = %r{https?://[^\s<>()\[\]`"']+|(?<![\w/])(?:[\w.-]+/[\w.-]+)?\#\d+(?!\w)|
                  (?<![\w-])GH-\d+(?![\w-])|\b(?:issue|pr|pull\ request)\s+\d+(?!\w|[,.]\d)}ix

      def initialize(query:, pull_request:)
        validate!(pull_request)
        @query = query
        @pr = pull_request
        @repository_url = pull_request.fetch('url').sub(%r{/pull/\d+\z}, '')
      end

      def cover?
        @pr.fetch('number').to_s == @query || closing_reference? || reference?(text)
      end

      def reference?(text)
        @query.match?(/\A\d+\z/) ? numeric_reference?(text) : tracker_reference?(text)
      end

      private

      def validate!(pull_request)
        valid = pull_request.is_a?(Hash) && pull_request['number'].is_a?(Integer) &&
                text_fields?(pull_request) && pull_request['closingIssuesReferences'].is_a?(Array)
        raise Error, 'GitHub returned incomplete pull request metadata.' unless valid

        raise Error, 'GitHub returned incomplete issue relationship metadata.' unless relationships?(pull_request)
      end

      def relationships?(pull_request)
        pull_request.fetch('closingIssuesReferences').all? { |ref| ref.is_a?(Hash) && ref['url'].is_a?(String) }
      end

      def text_fields?(pull_request)
        %w[title body url headRefName].all? { |key| pull_request[key].is_a?(String) }
      end

      def text = "#{@pr.fetch('title')}\n#{@pr.fetch('body')}"

      def tracker_reference?(text)
        text.match?(/(?<![\w-])#{Regexp.escape(@query)}(?![\w-])/i)
      end

      def closing_reference?
        @pr.fetch('closingIssuesReferences').any? do |ref|
          ref.fetch('url').casecmp?("#{@repository_url}/issues/#{@query}")
        end
      end

      def numeric_reference?(text)
        repository = @repository_url.split('/').last(2).join('/')
        text.scan(TOKENS).any? do |token|
          token = token.sub(/[.,;:!]+\z/, '')
          token.casecmp?("##{@query}") || token.casecmp?("GH-#{@query}") || token.casecmp?("#{repository}##{@query}") ||
            token.match?(%r{\A#{Regexp.escape(@repository_url)}/(?:issues|pull)/#{@query}(?:[?\#].*)?\z}i) ||
            token.match?(/\A(?:issue|pr|pull request)\s+#{@query}\z/i)
        end
      end
    end
  end
end
