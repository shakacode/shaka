# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative '../lib/instruction_tokens'

class InstructionTokensTest < Minitest::Test
  KEYS = { 'ANTHROPIC_API_KEY' => 'anthropic-key', 'OPENAI_API_KEY' => 'openai-key' }.freeze

  # Answers with one token per word, so each count follows from the text sent.
  def counting_transport(requests = [])
    lambda do |uri, headers, body|
      requests << [uri.host, headers, JSON.parse(body)]
      text = JSON.parse(body).then { |data| data['input'] || data['messages'].first['content'] }
      ['200', JSON.generate('input_tokens' => text.split.size)]
    end
  end

  def test_counts_baseline_and_head_with_each_provider
    rows = InstructionTokens.compare(before: 'one two', after: 'one two three', env: KEYS,
                                     transport: counting_transport)

    assert_equal([%w[anthropic claude-opus-5-5 2 3 1], %w[openai gpt-6.1-sol 2 3 1]],
                 rows.map { |row| row.values_at('provider', 'model', 'before', 'after', 'delta').map(&:to_s) })
  end

  def test_sends_each_key_and_model_to_its_own_provider
    requests = []
    InstructionTokens.compare(before: nil, after: 'one', env: KEYS, transport: counting_transport(requests))

    anthropic, openai = requests
    assert_equal ['api.anthropic.com', 'anthropic-key', 'claude-opus-5-5'],
                 [anthropic[0], anthropic[1]['x-api-key'], anthropic[2]['model']]
    assert_equal ['api.openai.com', 'Bearer openai-key', 'gpt-6.1-sol'],
                 [openai[0], openai[1]['Authorization'], openai[2]['model']]
  end

  def test_missing_baseline_counts_head_only
    rows = InstructionTokens.compare(before: nil, after: 'one', env: KEYS, transport: counting_transport)

    assert_equal([[nil, 1, nil]] * 2, rows.map { |row| row.values_at('before', 'after', 'delta') })
  end

  def test_missing_key_is_unknown_without_a_request
    requests = []
    rows = InstructionTokens.compare(before: 'a', after: 'b', env: KEYS.except('OPENAI_API_KEY'),
                                     transport: counting_transport(requests))

    assert_equal 0, rows.first['delta']
    assert_equal({ 'provider' => 'openai', 'model' => 'gpt-6.1-sol', 'tokens' => 'UNKNOWN',
                   'reason' => 'OPENAI_API_KEY is not set' }, rows.last)
    assert(requests.none? { |host, *| host == 'api.openai.com' })
  end

  def test_network_failure_is_unknown_with_its_reason
    offline = ->(*) { raise SocketError, 'getaddrinfo failed' }
    rows = InstructionTokens.compare(before: 'a', after: 'b', env: KEYS, transport: offline)

    assert_equal(['request failed: SocketError'] * 2, rows.map { |row| row['reason'] })
    assert(rows.all? { |row| row['tokens'] == 'UNKNOWN' && !row.key?('delta') })
  end

  def test_rejected_or_malformed_answers_are_unknown
    answers = { '401' => '{}', '200' => 'not json',
                '404' => '{"error":{"type":"invalid_request_error","code":"model_not_found","message":"key sk-x"}}' }
    reasons = answers.map do |status, body|
      InstructionTokens.compare(before: nil, after: 'a', env: KEYS, transport: ->(*) { [status, body] })
                       .first['reason']
    end
    reasons << InstructionTokens.compare(before: nil, after: 'a', env: KEYS,
                                         transport: ->(*) { ['200', '{"input_tokens":"7"}'] }).first['reason']

    assert_equal ['HTTP 401', 'response is not JSON', 'HTTP 404: invalid_request_error, model_not_found',
                  'response has no input_tokens count'], reasons
  end

  def test_any_unexpected_failure_is_unknown_rather_than_raised
    corrupt = ->(*) { raise Zlib::DataError, 'incorrect header check' }
    rows = InstructionTokens.compare(before: nil, after: 'a', env: KEYS, transport: corrupt)

    assert_equal(['request failed: Zlib::DataError'] * 2, rows.map { |row| row['reason'] })
  end
end
