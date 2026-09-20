# frozen_string_literal: true

require 'open3'
require_relative 'error'

module Shaka
  # Parses a Git origin URL into owner/name without calling GitHub.
  module GitOrigin
    module_function

    def from(root:)
      url, error, status = Open3.capture3('git', '-C', root, 'remote', 'get-url', 'origin')
      raise Error, "Cannot read origin for #{root}: #{error.strip}" unless status.success?

      parsed(url.strip)
    end

    def repository_name(root:)
      from(root:).fetch(:name)
    rescue Error
      File.basename(File.realpath(root))
    end

    def repository_name_from(url) = parsed(url).fetch(:name)

    def identity(url) = parsed(url).fetch(:identity)

    def canonical_url(url)
      parsed_url = parsed(url)
      identity = parsed_url.fetch(:identity)
      origin = parsed_url.fetch(:origin)
      origin.match?(%r{github\.com[:/]}) ? "https://github.com/#{identity}" : origin.sub(/\.git\z/, '')
    end

    def parsed(url)
      origin = url.strip
      path = origin.sub(%r{\A(?:git@|ssh://git@|https://|http://)[^/:]+[:/]}, '').sub(/\.git\z/, '')
      raise Error, "Cannot parse owner/name from origin #{origin}" unless path.match?(%r{\A[^/]+/[^/]+\z})

      { origin:, identity: path, name: File.basename(path) }
    end
    private_class_method :parsed
  end
end
