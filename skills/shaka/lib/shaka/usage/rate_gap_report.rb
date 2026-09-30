# frozen_string_literal: true

require 'digest'
require 'net/http'
require_relative '../issue_create'
require_relative 'missing_rates'
require_relative 'rate_gap_issue'

module Shaka
  # Opt-in publication of synthetic reproductions, with no native usage payload.
  class RateGapReport
    include RateGapIssue

    REPOSITORY = IssueCreate::REPOSITORY
    CATALOGS = {
      'openai' => 'https://developers.openai.com/api/docs/models',
      'anthropic' => 'https://platform.claude.com/docs/en/models/overview',
      'cursor' => 'https://cursor.com/docs/models-and-pricing'
    }.freeze

    def initialize(responses, inclusive_input:, rate_card:, github: IssueCreate, catalog: nil)
      @responses = responses
      @inclusive_input = inclusive_input
      @rate_card = rate_card
      @github = github
      @catalog = catalog || method(:read_catalog)
      @stage = 'classification'
    end

    def report
      safely do
        local = gaps(@rate_card)
        next 'Missing-rate reporting: no qualifying omissions.' if local.empty?

        revision, current, issues = snapshot
        local.map { |gap| safely { report_gap(gap, revision, current, issues) } }.join("\n")
      end
    end

    private

    def safely
      yield
    rescue Error, SystemCallError, JSON::ParserError, ArgumentError, KeyError, Timeout::Error, IOError,
           SocketError, OpenSSL::SSL::SSLError
      # Preserve completed results; error details can contain private source data.
      "Missing-rate reporting failed during #{@stage}; usage estimates remain unchanged. " \
      'Inspect Shaka issues before retrying.'
    end

    def snapshot
      @stage = 'repository verification'
      @github.verify_repository!
      @stage = 'trusted rate-card read'
      revision, current = current_card
      @stage = 'duplicate lookup'
      [revision, current, existing_issues]
    end

    def gaps(card) = MissingRates.new(@responses, inclusive_input: @inclusive_input, rate_card: card).gaps

    def api(path) = JSON.parse(@github.gh('api', "repos/#{REPOSITORY}/#{path}"))

    def current_card
      revision = current_revision
      file = api("contents/#{RateCard::PATH}?ref=#{revision}")
      unless file.is_a?(Hash) && file['encoding'] == 'base64' && file['content'].is_a?(String)
        raise Error, 'Invalid rate card'
      end

      source = file.fetch('content').delete("\n").unpack1('m0').force_encoding(Encoding::UTF_8)
      [revision, RateCard.load_source(source)]
    end

    def current_revision
      commits = api('commits?per_page=1')
      raise Error, 'Invalid commits' unless commits.is_a?(Array) && commits.first.is_a?(Hash)

      revision = commits.first.fetch('sha')
      raise Error, 'Invalid revision' unless revision.is_a?(String) && revision.match?(/\A[0-9a-f]{40}\z/)

      revision
    end

    def existing_issues
      # List all states directly: a freshly filed issue need not be search-indexed yet.
      (1..100).each_with_object([]) do |page, issues|
        batch = api("issues?state=all&per_page=100&page=#{page}")
        raise Error, 'Invalid issues response' unless batch.is_a?(Array) && batch.all?(Hash)

        issues.concat(batch.reject { |issue| issue.key?('pull_request') })
        return issues if batch.size < 100
      end
      raise Error, 'Issue listing limit reached'
    end

    def report_gap(gap, revision, current, issues)
      @stage = 'duplicate lookup'
      marker = "<!-- shaka-missing-rate: #{Digest::SHA256.hexdigest(gap.join('/'))} -->"
      issue = issues.find { |entry| matching_issue?(entry, marker, gap[1]) }
      return existing_url(issue) if issue
      unless gaps(current).include?(gap)
        return 'Missing-rate reporting: current Shaka already prices this scenario; update the installation.'
      end

      file_gap(gap, revision, marker)
    end

    def existing_url(issue)
      url = issue['html_url']
      raise Error, 'Invalid issue URL' unless url.is_a?(String) && IssueCreate::ISSUE_URL.match?(url)

      "Missing-rate report: #{url}"
    end

    def file_gap(gap, revision, marker)
      provider, model, scenario = gap
      @stage = 'public model verification'
      unless verified_scenario?(gap)
        return 'Missing-rate reporting: model identity not verified in the official public catalog.'
      end

      @stage = 'issue creation'
      url = @github.create("Missing cost rate: #{provider}/#{model} (#{scenario})\n#{body(gap, revision, marker)}\n")
      "Missing-rate report: #{url}"
    end

    def verified_scenario?(gap)
      provider, model, scenario = gap
      @catalogs ||= {}
      url = catalog_url(gap)
      catalog = @catalogs[url] ||= @catalog.call(url)
      name = provider == 'cursor' && scenario == 'fast' ? "#{model}-fast" : model
      public_model?(catalog, name)
    end
  end
end
