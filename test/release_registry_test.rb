# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/shaka_release/publish'

class ReleaseRegistryTest < Minitest::Test
  def test_reads_the_published_digest_or_nil_when_absent
    assert_equal 'a' * 64, lookup(response(Net::HTTPOK, '200', JSON.generate('sha' => 'a' * 64)))
    assert_nil lookup(response(Net::HTTPNotFound, '404', 'This rubygem could not be found.'))
  end

  def test_other_answers_and_network_failures_refuse
    assert_lookup_refused(response(Net::HTTPInternalServerError, '500', ''), 'answered 500')
    assert_lookup_refused(response(Net::HTTPOK, '200', 'not json'), 'Cannot read shaka')
    assert_lookup_refused(response(Net::HTTPOK, '200', '{}'), 'Cannot read shaka')
    assert_lookup_refused(response(Net::HTTPOK, '200', '{"sha":null}'), 'without a SHA-256')
    assert_lookup_refused(-> { raise OpenSSL::SSL::SSLError, 'certificate' }, 'certificate')
    assert_lookup_refused(-> { raise Net::OpenTimeout }, 'Cannot read shaka')
  end

  private

  def lookup(answer)
    http = ->(uri) { answer.respond_to?(:call) ? answer.call : check(uri, answer) }
    ShakaRelease::Registry.new(http:).published_sha256('1.2.0')
  end

  def check(uri, answer)
    assert_equal 'https://rubygems.org/api/v2/rubygems/shaka/versions/1.2.0.json', uri.to_s
    answer
  end

  def assert_lookup_refused(answer, message)
    error = assert_raises(Shaka::Error) { lookup(answer) }
    assert_includes error.message, message
  end

  def response(type, code, body)
    type.new('1.1', code, '').tap do |answer|
      answer.instance_variable_set(:@body, body)
      answer.instance_variable_set(:@read, true)
    end
  end
end
