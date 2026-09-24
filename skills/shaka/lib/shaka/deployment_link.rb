# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Resolves `deployment: auto` from the GitHub Deployments API. Providers word their
  # PR comments differently, but a successful deployment status carries the same
  # `environment_url` that GitHub shows as "View deployment".
  module DeploymentLink
    AUTO = 'auto'

    module_function

    def resolve(content, github)
      return content unless content['deployment'] == AUTO

      content.merge('deployment' => live_url(github, github.snapshot.fetch('headRefOid')) || 'none')
    end

    # Only the head commit counts, so a link never describes code the PR no longer holds.
    def live_url(github, head)
      deployments = github.api_list("repos/#{github.repository}/deployments?sha=#{head}&per_page=100")
      deployments.sort_by { |deployment| deployment['created_at'].to_s }.reverse_each do |deployment|
        latest = github.api_list("repos/#{github.repository}/deployments/#{deployment.fetch('id')}/statuses?per_page=1")
                       .first
        url = latest['environment_url'].to_s if latest && latest['state'] == 'success'
        return url if url&.start_with?('https://')
      end
      nil
    end
  end
end
