# frozen_string_literal: true

require 'json'
require 'net/http'

module ShakaRelease
  # Reads one published shaka version from the RubyGems API.
  class Registry
    URL = 'https://rubygems.org/api/v2/rubygems/shaka/versions/%s.json'

    # The SHA-256 RubyGems recorded for the gem, or nil when that version is not published.
    def published_sha256(version)
      response = Net::HTTP.get_response(URI(format(URL, version)))
      return nil if response.is_a?(Net::HTTPNotFound)
      raise Shaka::Error, "RubyGems answered #{response.code} for shaka #{version}" unless
        response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch('sha')
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError, KeyError => e
      raise Shaka::Error, "Cannot read shaka #{version} from RubyGems: #{e.message}"
    end
  end
end
