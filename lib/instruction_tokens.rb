# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'timeout'
require_relative '../skills/shaka/lib/shaka/defaults'

# Counts the same text with each provider's token-counting endpoint. A provider without a key,
# network, or valid answer is UNKNOWN with a reason; counting never raises.
module InstructionTokens
  MODELS = Shaka::Defaults.fetch('runtime', 'instruction_tokens')
  TIMEOUT_SECONDS = 30

  Provider = Data.define(:uri, :key_variable, :headers, :body)

  PROVIDERS = {
    'anthropic' => Provider.new(
      uri: URI('https://api.anthropic.com/v1/messages/count_tokens'), key_variable: 'ANTHROPIC_API_KEY',
      headers: ->(key) { { 'x-api-key' => key, 'anthropic-version' => '2023-06-01' } },
      body: ->(model, text) { { model:, messages: [{ role: 'user', content: text }] } }
    ),
    'openai' => Provider.new(
      uri: URI('https://api.openai.com/v1/responses/input_tokens'), key_variable: 'OPENAI_API_KEY',
      headers: ->(key) { { 'Authorization' => "Bearer #{key}" } },
      body: ->(model, text) { { model:, input: text } }
    )
  }.freeze

  # One row per provider. `before` is nil when there is no baseline text to count.
  def self.compare(before:, after:, env: ENV, transport: method(:post))
    PROVIDERS.map do |name, provider|
      model = MODELS.fetch(name)
      counter = ->(text) { count(provider, model, text, env, transport) }
      row(name, model, before && counter.call(before), counter.call(after))
    end
  end

  def self.row(name, model, before, after)
    unknown = [after, before].compact.find { |result| result.key?(:reason) }
    return { 'provider' => name, 'model' => model, 'tokens' => 'UNKNOWN', 'reason' => unknown[:reason] } if unknown

    old = before&.fetch(:tokens)
    { 'provider' => name, 'model' => model, 'before' => old, 'after' => after[:tokens],
      'delta' => old && (after[:tokens] - old) }
  end

  def self.count(provider, model, text, env, transport)
    key = env.fetch(provider.key_variable, '').strip
    return { reason: "#{provider.key_variable} is not set" } if key.empty?

    status, body = transport.call(provider.uri, provider.headers.call(key),
                                  JSON.generate(provider.body.call(model, text)))
    status.to_s == '200' ? parse(body) : { reason: rejection(status, body) }
  rescue StandardError => e # Any failure to count leaves the report running; the class never carries the key.
    { reason: "request failed: #{e.class}" }
  end

  # The provider's error type and code tell a wrong model from a bad key. Its message can echo the key, so it stays out.
  def self.rejection(status, body)
    error = JSON.parse(body.to_s)['error']
    labels = error.values_at('type', 'code').grep(/\A[a-z_]{1,64}\z/).uniq if error.is_a?(Hash)
    labels&.any? ? "HTTP #{status}: #{labels.join(', ')}" : "HTTP #{status}"
  rescue JSON::ParserError
    "HTTP #{status}"
  end

  def self.parse(body)
    data = JSON.parse(body.to_s)
    tokens = data['input_tokens'] if data.is_a?(Hash)
    tokens.is_a?(Integer) && !tokens.negative? ? { tokens: } : { reason: 'response has no input_tokens count' }
  rescue JSON::ParserError
    { reason: 'response is not JSON' }
  end

  def self.post(uri, headers, body)
    request = Net::HTTP::Post.new(uri, headers.merge('Content-Type' => 'application/json'))
    request.body = body
    response = Timeout.timeout(TIMEOUT_SECONDS) do
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT_SECONDS,
                                          read_timeout: TIMEOUT_SECONDS, max_retries: 0) do |http|
        http.request(request)
      end
    end
    [response.code, response.body]
  end
  private_class_method :row, :count, :rejection, :parse, :post
end
