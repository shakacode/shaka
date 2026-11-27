# frozen_string_literal: true

require 'json'
require 'net/http'

module ShakaRelease
  # Reads one published shaka version from the RubyGems API.
  class Registry
    HOST = 'https://rubygems.org'
    URL = "#{HOST}/api/v2/rubygems/shaka/versions/%s.json".freeze

    # `http` takes a URI and returns a Net::HTTPResponse; tests replace it.
    def initialize(http: Net::HTTP.method(:get_response)) = @http = http

    # The SHA-256 RubyGems recorded for the gem, or nil when that version is not published.
    def published_sha256(version)
      response = @http.call(URI(format(URL, version)))
      return nil if response.is_a?(Net::HTTPNotFound)
      raise Shaka::Error, "RubyGems answered #{response.code} for shaka #{version}" unless
        response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch('sha')
    rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError,
           KeyError, TypeError => e
      raise Shaka::Error, "Cannot read shaka #{version} from RubyGems: #{e.message}"
    end
  end
end
