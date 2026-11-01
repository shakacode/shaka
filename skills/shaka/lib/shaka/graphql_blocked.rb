# frozen_string_literal: true

module Shaka
  # Recognizes a GitHub that refuses GraphQL while REST still works, as Claude Code cloud
  # sessions do. Callers that can answer over REST switch only on this refusal; any other
  # failure keeps its own report.
  module GraphqlBlocked
    module_function

    # gh subcommands such as `gh repo view` name the GraphQL endpoint beside the status.
    def gh_stderr?(stderr)
      text = stderr.to_s
      text.include?('HTTP 403') && text.include?('api.github.com/graphql')
    end
  end
end
