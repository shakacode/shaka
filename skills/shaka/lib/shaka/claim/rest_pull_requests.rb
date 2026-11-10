# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative '../public_comments/bounded_list'

module Shaka
  class Claim
    # Reads what `gh pr list` gives claim over REST, for sessions where GitHub refuses GraphQL.
    class RestPullRequests
      # REST names no closing issues, so a PR linked to the issue only from GitHub's sidebar is
      # missed. Claim names the field rather than reading "no links" from the empty list it uses.
      UNKNOWN_FIELDS = %w[closingIssuesReferences].freeze
      MAX_PAGES = 10
      PAGE_SIZE = PublicComments::BoundedList::PAGE_SIZE
      NAME = %r{\A[\w.-]+/[\w.-]+\z}

      def initialize(capture) = @capture = capture

      def list(search)
        stable { search.empty? ? open_pull_requests : searched_numbers(search.last) }
      end

      def api_list(path) = array(api(path), 'GitHub pull request list')

      private

      # REST pages by offset, so a pull request closing between pages shifts another onto a page
      # already read. A list longer than one page is read twice and must come back the same.
      def stable
        rows = yield
        return rows if rows.length < PAGE_SIZE || yield.map { |row| row['number'] } == rows.map { |row| row['number'] }

        raise Error, 'GitHub PR inventory changed during ownership search.'
      end

      def open_pull_requests
        PublicComments::BoundedList.new(self, max_pages: MAX_PAGES, label: 'GitHub open pull request list')
                                   .call("repos/#{repository}/pulls").map { |pull| row(pull) }
      end

      # REST sends null for an empty body; a missing key stays missing so References refuses it.
      # The description path never reaches References, so the branch name is checked here.
      def row(pull)
        raise Error, 'GitHub returned incomplete pull request metadata.' unless pull.dig('head', 'ref').is_a?(String)

        { 'number' => pull['number'], 'title' => pull['title'], 'url' => pull['html_url'],
          'headRefName' => pull.dig('head', 'ref'), 'body' => pull.key?('body') ? pull['body'] || '' : nil,
          'closingIssuesReferences' => [] }
      end

      # The query `gh pr list --search` sends to GitHub's search, read one page at a time.
      def searched_numbers(query)
        items = []
        (1..MAX_PAGES).each do |page|
          batch = search_page(query, page)
          items.concat(batch)
          return items.map { |item| item.slice('number') } if batch.length < PAGE_SIZE
        end
        raise Error, 'GitHub pull request search reached its limit; ownership is incomplete.'
      end

      def search_page(query, page)
        result = api(['-X', 'GET', 'search/issues', '-f', "q=repo:#{repository} is:pr is:open #{query}",
                      '-f', "per_page=#{PAGE_SIZE}", '-f', "page=#{page}"])
        unless result.is_a?(Hash) && result['incomplete_results'] == false && result['items'].is_a?(Array) &&
               result['items'].all?(Hash)
          raise Error, 'GitHub pull request search returned incomplete results.'
        end

        result['items']
      end

      # gh fills `{owner}/{repo}` from the checkout's remotes without GraphQL, as `gh pr list` would.
      def repository
        @repository ||= begin
          found = api('repos/{owner}/{repo}')
          name = found['full_name'] if found.is_a?(Hash)
          raise Error, 'GitHub did not name the repository.' unless name.is_a?(String) && name.match?(NAME)

          name
        end
      end

      def api(arguments)
        JSON.parse(@capture.call(['gh', 'api', *Array(arguments)]))
      rescue JSON::ParserError
        raise Error, 'GitHub returned invalid JSON.'
      end

      def array(value, label)
        raise Error, "#{label} must be an array." unless value.is_a?(Array)

        value
      end
    end
  end
end
