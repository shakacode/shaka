# frozen_string_literal: true

require 'uri'
require 'digest'
require_relative '../public_comments/bounded_list'
require_relative 'reference'
require_relative '../github'
require_relative '../publication/text'

module Shaka
  module Trial
    # Publishes tester feedback, not an automatic adoption or merge decision.
    class Report
      RESULT = %r{\Ahttps://github\.com/([\w-]+/[\w.-]+)/pull/([1-9]\d*)\z}
      # A github.com link with an optional scheme, www., and port, not continuing another host or address.
      SUMMARY_LINK = %r{(?<![\w.@/:-])(?:(?:(?<scheme>https?):)?//)?(?:www\.)?github\.com(?::(?<port>\d+))?
                        (?<path>/[^\s)<>\[\]`"|]*)}ix

      def initialize(url, content, github: nil, results: nil)
        @url = url
        @number = Reference.number(url)
        @content = content
        @github = github || GitHub.new(Reference::REPOSITORY, @number)
        @results = results || @github
      end

      def run
        validate
        pull = @github.api("repos/#{Reference::REPOSITORY}/pulls/#{@number}")
        Reference.public_candidate!(pull)
        verify_commit
        verify_result
        verify_summary_links
        key = "field-trial-#{Digest::SHA256.hexdigest("#{@id}:#{@head}")[0, 52]}"
        @github.reply(body: body, key: key)
      end

      private

      def verify_commit
        commits = PublicComments::BoundedList.new(@github, max_pages: 3, label: 'Trial candidate commits')
                                             .call("repos/#{Reference::REPOSITORY}/pulls/#{@number}/commits")
        return if commits.any? { |commit| commit['sha'] == @head }

        raise Error, 'Reported revision is not in the candidate PR; a force-pushed trial needs manual feedback.'
      end

      def validate
        validate_identity
        @verdict = @content['verdict']
        raise Error, 'Trial verdict must be keep, revise, or drop.' unless %w[keep revise drop].include?(@verdict)

        @summary = PublicationText.summary_text(@content['summary'], 'trial summary')
        @result = @content['result_url']
        validate_result
      end

      def validate_identity
        raise Error, 'Trial report must be an object.' unless @content.is_a?(Hash)

        @id = @content['id']
        raise Error, 'Supply a public trial id using 1–48 letters, digits, or hyphens.' unless
          @id.is_a?(String) && @id.match?(/\A[a-zA-Z0-9][a-zA-Z0-9-]{0,47}\z/)

        @head = Reference.head(@content['candidate_head'])
      end

      def validate_result
        return if @result.is_a?(String) && RESULT.match?(@result) && @content['private_result'] != true
        return if @result.nil? && @content['private_result'] == true

        raise Error, 'Supply a public result_url, or private_result: true with no result URL.'
      end

      def verify_result
        return unless @result

        repository, number = RESULT.match(@result).captures
        public_repository!(repository)
        result = @results.api("repos/#{repository}/pulls/#{number}")
        return if result['body'].to_s.include?("https://github.com/#{Reference::REPOSITORY}/commit/#{@head}")

        raise Error, 'Result PR must record the exact Shaka revision in its workflow provenance.'
      end

      # Every GitHub mention must be a link this check can read; anything else is refused unchecked.
      def verify_summary_links
        links = []
        remainder = @summary.gsub(SUMMARY_LINK) do
          links << Regexp.last_match
          ' '
        end
        raise Error, 'Write each GitHub link in the summary as https://github.com/OWNER/REPO.' if
          mentions_github?(remainder)

        links.map { |link| summary_repository(link) }.each { |repository| public_repository!(repository) }
      end

      # Browsers decode percent escapes and fold compatibility characters in a host, so the search does too.
      def mentions_github?(text)
        URI::DEFAULT_PARSER.unescape(text).scrub('').unicode_normalize(:nfkc).downcase.include?('github.com')
      end

      def summary_repository(link)
        raise Error, 'GitHub links in the summary must use the default port.' unless default_port?(link)
        raise Error, 'GitHub links in the summary must not contain . or .. path segments.' if
          path_segments(link[:path]).intersect?(%w[. ..])

        Array(path_segments(link[:path].sub(/[.,;:!?]+\z/, ''))[1, 2]).join('/')
      end

      def default_port?(link)
        link[:port].nil? || link[:port].to_i == (link[:scheme]&.downcase == 'http' ? 80 : 443)
      end

      def path_segments(path)
        URI::DEFAULT_PARSER.unescape(URI.parse("https://github.com#{path}").path).split('/')
      rescue URI::InvalidURIError
        raise Error, 'Supply full GitHub repository URLs in the summary.'
      end

      def public_repository!(repository)
        raise Error, 'Supply full GitHub repository URLs in the summary.' unless
          repository.match?(%r{\A[\w-]+/[\w.-]+\z})

        metadata = @results.api("repos/#{repository}")
        return if metadata['private'] == false && metadata['visibility'] == 'public'

        raise Error, 'Private or unverifiable result links cannot be published on the public Shaka PR.'
      end

      def body
        result = @result ? "[Result PR](#{@result})" : 'Private result; link withheld'
        <<~MARKDOWN
          ## Field trial — #{@id}

          Reported by the tester; this feedback is not an adoption or merge approval.

          - Shaka candidate: #{@url}
          - Tested revision: [`#{@head[0, 7]}`](https://github.com/#{Reference::REPOSITORY}/commit/#{@head})
          - Result: #{result}
          - Verdict: **#{@verdict}**

          #{@summary}
        MARKDOWN
      end
    end
  end
end
