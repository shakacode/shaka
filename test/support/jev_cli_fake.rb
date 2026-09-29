# frozen_string_literal: true

require_relative '../../skills/shaka-jev/lib/shaka_jev/analysis'

module ShakaJev
  class Analysis
    def call(pr_url:, head:, evidence:)
      expected = ['test-key', 'https://github.com/shakacode/shaka/pull/302', 'a' * 40, "Public evidence.\n"]
      raise Error, 'Unexpected command input' unless [@api_key, pr_url, head, evidence] == expected

      { 'model' => 'jev-test', 'evidence_sha256' => Digest::SHA256.hexdigest(evidence),
        'estimated_input_cost_usd' => 0.000001 }
    end
  end
end
