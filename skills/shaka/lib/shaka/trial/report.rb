# frozen_string_literal: true

require 'uri'
require_relative 'reference'
require_relative '../github'
require_relative '../publication/text'

module Shaka
  module Trial
    # Publishes tester feedback, not an automatic adoption or merge decision.
    class Report
      RESULT = %r{\Ahttps://github\.com/([\w-]+/[\w.-]+)/pull/([1-9]\d*)\z}

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
        mark_evaluation if pull['state'] == 'open'
        @github.reply(body: body, key: "field-trial-#{@id}-#{@head}")
      end

      private

      def verify_commit
        commit = @github.api("repos/#{Reference::REPOSITORY}/commits/#{@head}")
        raise Error, 'Reported Shaka revision is unavailable.' unless commit['sha'] == @head
      end

      def mark_evaluation
        @github.api("repos/#{Reference::REPOSITORY}/issues/#{@number}/labels",
                    method: 'POST', fields: { labels: ['eval-required'] }, expected: Array)
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

      def verify_summary_links
        @summary.scan(%r{https?://github\.com/[^\s)<>]+}i).each do |url|
          path = URI::DEFAULT_PARSER.unescape(URI.parse(url).path)
          repository = path.split('/')[1, 2].join('/')
          public_repository!(repository)
        end
      end

      def public_repository!(repository)
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
          - Tested revision: [`#{@head}`](https://github.com/#{Reference::REPOSITORY}/commit/#{@head})
          - Result: #{result}
          - Verdict: **#{@verdict}**

          #{@summary}
        MARKDOWN
      end
    end
  end
end
