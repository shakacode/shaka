# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative '../skills/shaka-jev/lib/shaka_jev/analysis'

class JevAnalysisTest < Minitest::Test
  HEAD = 'a' * 40
  URL = 'https://github.com/shakacode/shaka/pull/302'
  OUTPUT = {
    model: 'jev-1.13.0',
    answers: {
      validation_supported: { type: 'noul', noul: 0.91 },
      material_concern_open: { type: 'noul', noul: 0.13 }
    },
    usage: { input_tokens: 2500, output_tokens: 25 }
  }.freeze

  def test_sends_one_request_with_fixed_questions_and_reports_usage
    sent = nil
    client = lambda do |uri, request|
      sent = [uri, request]
      response(200, OUTPUT)
    end
    result = ShakaJev::Analysis.new(api_key: 'test-key', client: client).call(
      pr_url: URL, head: HEAD, evidence: 'Public validation and review evidence.'
    )

    assert_request(sent)
    assert_result(result)
  end

  def test_rejects_missing_key_before_sending
    client = ->(*) { flunk 'must not send' }
    assert_raises(ShakaJev::Error) do
      ShakaJev::Analysis.new(api_key: '', client: client).call(pr_url: URL, head: HEAD, evidence: 'Public')
    end
  end

  def test_rejects_malformed_model_output_without_a_verdict
    client = ->(*) { response(200, { answers: { validation_supported: { noul: 0.8 } } }) }
    assert_raises(ShakaJev::Error) do
      ShakaJev::Analysis.new(api_key: 'test-key', client: client).call(pr_url: URL, head: HEAD,
                                                                       evidence: 'Public')
    end
  end

  def test_api_errors_expose_status_without_response_body
    client = ->(*) { response(401, { secret: 'must not appear' }) }
    error = assert_raises(ShakaJev::Error) do
      ShakaJev::Analysis.new(api_key: 'test-key', client: client).call(pr_url: URL, head: HEAD,
                                                                       evidence: 'Public')
    end
    assert_match(/401/, error.message)
    refute_match(/secret/, error.message)
  end

  private

  def assert_request(sent)
    payload = JSON.parse(sent.last.body)
    observed = [sent.first.to_s, sent.last['Authorization'], payload.fetch('model'),
                payload.fetch('questions').keys.sort]
    expected = ['https://api.typesafe.ai/v1/systemone', 'Bearer test-key', 'jev-latest',
                %w[material_concern_open validation_supported]]
    assert_equal expected, observed
    assert_includes payload.fetch('state'), HEAD
  end

  def assert_result(result)
    assert_in_delta 0.91, result.fetch('answers').fetch('validation_supported')
    assert_equal 2500, result.fetch('input_tokens')
    assert_in_delta 0.000105, result.fetch('estimated_cost_usd'), 0.000000001
    assert_match(/\A[0-9a-f]{64}\z/, result.fetch('evidence_sha256'))
  end

  def response(code, body)
    Struct.new(:code, :body).new(code.to_s, JSON.generate(body))
  end
end
