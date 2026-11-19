# frozen_string_literal: true

require_relative 'error'

module Shaka
  # GitHub refused GraphQL for this session while REST may still answer, as Claude Code cloud
  # sessions do. Only commands that can read the same evidence over REST rescue it; every other
  # caller sees the same failure as any other Error.
  class GraphqlRefused < Error
    # An HTTP 403 from the GraphQL endpoint. `gh api graphql` names the status alone, since the
    # request path already says GraphQL; other gh commands append the endpoint URL to the status.
    def self.refusal?(stderr, graphql_request: false)
      stderr.include?('HTTP 403') && (graphql_request || stderr.include?('api.github.com/graphql'))
    end

    # The error for a failed gh call: a refusal when GitHub refused GraphQL, otherwise a plain Error.
    def self.for_gh(argv, message, stderr)
      (refusal?(stderr, graphql_request: argv[1, 2] == %w[api graphql]) ? self : Error).from_gh(message, stderr)
    end
  end
end
