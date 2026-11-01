# frozen_string_literal: true

require 'json'
require_relative 'check'
require_relative '../error'
require_relative '../git_origin'
require_relative '../graphql_blocked'

module Shaka
  class Doctor
    # Whether this account can publish to the checkout's GitHub repository.
    class RepositoryAccess
      include Check

      WRITER = %w[ADMIN MAINTAIN WRITE].freeze
      # REST reports permissions as booleans; the strongest true one names the role.
      REST_ROLES = { 'admin' => 'ADMIN', 'maintain' => 'MAINTAIN', 'push' => 'WRITE', 'triage' => 'TRIAGE',
                     'pull' => 'READ' }.freeze

      # `run` takes an argv and a chdir keyword and returns stdout, stderr, and success, like Checks#run.
      def initialize(root:, run:)
        @root = root
        @run = run
      end

      # This answers authentication and permission together, for the one repository that
      # matters, so a stale credential on an unrelated host cannot block a usable setup.
      # Any unresolved repository is a failure: doctor must never pass write access it did
      # not establish.
      def call
        out, error, ok = @run.call(['gh', 'repo', 'view', '--json', 'nameWithOwner,viewerPermission'], chdir: @root)
        return permission(JSON.parse(out)) if ok
        return rest_repository_access if GraphqlBlocked.gh_stderr?(error)

        unreachable_repository(first_line(error))
      rescue JSON::ParserError
        unreachable_repository('gh returned a response that is not repository JSON')
      end

      private

      # `gh repo view` needs GraphQL, so the origin remote names the repository instead.
      def rest_repository_access
        origin = GitOrigin.from(root: @root)
        return unreachable_repository("origin is not on github.com: #{origin[:host]}") unless
          origin[:host].casecmp?('github.com')

        out, error, ok = @run.call(['gh', 'api', "repos/#{origin[:identity]}"], chdir: @root)
        return unreachable_repository(first_line(error)) unless ok

        parsed = JSON.parse(out)
        permission({ 'nameWithOwner' => parsed['full_name'], 'viewerPermission' => rest_role(parsed) },
                   source: ' (read over REST: GitHub GraphQL is unavailable here)')
      rescue Error => e
        unreachable_repository(e.message)
      end

      def rest_role(parsed)
        permissions = parsed['permissions'] if parsed.is_a?(Hash)
        REST_ROLES.find { |key, _| permissions[key] == true }&.last if permissions.is_a?(Hash)
      end

      def unreachable_repository(reason)
        check('Repository access', 'failed', "no writable GitHub repository resolved here: #{reason}",
              guidance: 'Run doctor inside the checkout you publish from, and sign in with `gh auth login`.')
      end

      # Healthy has to name the repository and the permission it actually saw; a response
      # missing either one establishes nothing, however well-formed its JSON is.
      def permission(parsed, source: '')
        repository = stated(parsed, 'nameWithOwner')
        level = stated(parsed, 'viewerPermission')
        return unreachable_repository('gh did not report a repository and a permission') unless repository && level
        if WRITER.include?(level)
          return check('Repository access', 'healthy', "#{repository} is writable as #{level}#{source}")
        end

        check('Repository access', 'failed', "#{repository} is not writable (#{level})",
              guidance: 'Use an account with write access, or re-authenticate with `gh auth login`.')
      end

      # Present, a string, and not blank: anything less states nothing.
      def stated(parsed, field)
        value = parsed[field] if parsed.is_a?(Hash)
        value if value.is_a?(String) && !value.empty?
      end
    end
  end
end
