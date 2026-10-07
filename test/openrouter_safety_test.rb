# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'openrouter_fixture'
require 'shaka/usage/command'

class OpenrouterSafetyTest < Minitest::Test
  include OpenrouterFixture

  def test_multiline_key_fails_before_transport_without_disclosing_it
    with_adapter do |cli, _options, _report|
      with_key("fixture-private-key\nsecond-line") do
        with_request(->(*) { flunk 'invalid credentials must not reach the API' }) do
          result = cli.run('diff')
          assert_equal 'credentials_invalid', result.fetch('failure_stage')
          refute result.fetch('attempted')
          refute_includes JSON.generate(result), 'fixture-private-key'
        end
      end
    end
  end

  def test_transport_rejects_multiline_header_without_disclosing_the_key
    with_key("fixture-private-key\nsecond-line") do
      error = assert_raises(Shaka::Error) do
        Shaka::OpenrouterReview.request('diff', model: MODEL, effort: 'high', timeout: 1)
      end
      refute_includes error.message, 'fixture-private-key'
    end
  end

  def test_metadata_tokens_retain_slugs_and_reject_autolink_urls
    assert_equal MODEL, Shaka::OpenrouterReview.token(MODEL)
    %w[https://evil.example/x www.evil.example/x ftp://evil.example/x].each do |value|
      assert_nil Shaka::OpenrouterReview.token(value)
      assert_equal 'UNKNOWN', Shaka::Usage.allocate.send(:safe, value)
      assert_equal 'UNKNOWN', Shaka::CostEstimate.new([]).send(:safe, value)
    end
  end
end
