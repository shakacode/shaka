# frozen_string_literal: true

module Shaka
  # Public-only issue rendering and recognition for missing rates.
  module RateGapIssue
    MODEL_END = /(?=\s*(?:\z|[<>"',;|]|(?:cost|rates?|pricing|price)\b))/i

    def matching_issue?(entry, marker, model)
      body = entry['body']
      if body.is_a?(String) && body.include?('<!-- shaka-missing-rate: ')
        return body.lines.map(&:strip).include?(marker)
      end

      title = entry['title']
      public_model?(title, model) && title.match?(/\b(?:rate|rates|pricing|price|cost)\b/i)
    end

    def public_model?(catalog, model)
      # A complete identity can use display spaces, but never a variant's prefix.
      name = Regexp.escape(model).gsub('\\-', '[- ]')
      catalog.is_a?(String) && catalog.match?(/(?<![a-z0-9._:-])#{name}(?![a-z0-9._:-])#{MODEL_END}/i)
    end

    def catalog_url(gap)
      provider, _model, scenario = gap
      return 'https://learn.chatgpt.com/docs/pricing' if provider == 'openai' && scenario == 'credits'

      RateGapReport::CATALOGS.fetch(provider)
    end

    def body(gap, revision, marker)
      provider, model, scenario = gap
      <<~MARKDOWN
        #{marker}
        Provider/model: `#{provider}/#{model}`. Missing pricing scenario: `#{scenario}`.
        Rate-card revision: `#{revision}` in `#{RateCard::PATH}`.
        Public model catalog: #{catalog_url(gap)}

        #{reproduction(gap)}
        Verify official prices for this scenario, add the rate and source link, test the
        pricing behavior, and deliver a reviewed PR. Keep estimates UNKNOWN until verified.
      MARKDOWN
    end

    def reproduction(gap)
      provider, model, scenario = gap
      billing = %w[credits api].include?(scenario) ? 'standard' : scenario
      <<~MARKDOWN
        Reproduce at that revision with a synthetic CostEstimate response: configuration
        ["#{provider}", "#{model}", "#{model}", "UNKNOWN"], billing_mode "#{billing}",
        usage input_tokens=100, cached_input_tokens=0, cache_write_input_tokens=0,
        cache_write_5m_input_tokens=0, cache_write_1h_input_tokens=0, output_tokens=10,
        web_search_requests=0. Set inclusive_input=#{provider != 'anthropic'}.
        The #{scenario} estimate is UNKNOWN because its rate-card entry is missing.
      MARKDOWN
    end

    def read_catalog(url)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
        http.get(uri.request_uri)
      end
      raise Error, 'Public catalog unavailable' unless response.is_a?(Net::HTTPSuccess)

      response.body
    rescue StandardError
      raise Error, 'Public catalog unavailable'
    end
  end
end
