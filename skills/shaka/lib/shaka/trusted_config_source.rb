# frozen_string_literal: true

require 'open3'
require_relative 'repository_config'

module Shaka
  # Reads repository policy from an immutable commit resolved from a trusted ref.
  class TrustedConfigSource
    def initialize(root:)
      @root = root
    end

    def read(ref)
      sha = resolve(ref)
      source, error, status = Open3.capture3('git', '-C', @root, 'show', "#{sha}:#{RepositoryConfig::PATH}")
      raise Error, "Cannot read #{RepositoryConfig::PATH} at #{ref}: #{error.strip}" unless status.success?

      source
    end

    private

    def resolve(ref)
      arguments = ['git', '-C', @root, 'rev-parse', '--verify', '--end-of-options', "#{ref}^{commit}"]
      sha, error, status = Open3.capture3(*arguments)
      raise Error, "Invalid trusted ref #{ref}: #{error.strip}" unless status.success?

      sha.strip
    end
  end
end
