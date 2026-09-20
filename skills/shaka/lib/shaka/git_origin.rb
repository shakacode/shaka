# frozen_string_literal: true

require 'open3'
require_relative 'error'

module Shaka
  # Parses a Git origin URL into owner/name without calling GitHub.
  module GitOrigin
    HOST_AND_PATH = %r{\A(?:git@|ssh://git@|https://|http://)(?:[^/@]+@)?([^/:]+)[:/](.+)}

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
      return "https://github.com/#{identity}" if parsed_url.fetch(:host) == 'github.com'

      parsed_url.fetch(:origin).sub(%r{\A(https?://)[^/@]+@}, '\1').delete_suffix('.git')
    end

    def parsed(url)
      origin = url.strip
      match = HOST_AND_PATH.match(origin)
      path = match && match[2].delete_suffix('.git')
      raise Error, "Cannot parse owner/name from origin #{origin}" unless path&.match?(%r{\A[^/]+/[^/]+\z})

      { origin:, host: match[1], identity: path, name: File.basename(path) }
    end
    private_class_method :parsed
  end
end
