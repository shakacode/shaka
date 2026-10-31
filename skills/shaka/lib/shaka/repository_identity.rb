# frozen_string_literal: true

require_relative 'gitlab'

module Shaka
  # Earlier GitHub identity or an explicitly host-qualified GitLab evidence identity.
  module RepositoryIdentity
    def self.valid?(value)
      return false unless value.is_a?(String)
      return true if value.match?(%r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z})
      return false unless value.start_with?('gitlab:')

      host, project = value.delete_prefix('gitlab:').split('/', 2)
      GitLab.new(host:, project:)
      host == host.downcase
    rescue Error
      false
    end
  end
end
