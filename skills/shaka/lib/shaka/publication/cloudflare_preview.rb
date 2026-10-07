# frozen_string_literal: true

require_relative 'links'

module Shaka
  # Cloudflare Pages exposes its immutable preview in app-authored check output,
  # even when it creates no GitHub deployment. Never parse arbitrary PR comments.
  module CloudflarePreview
    APP_ID = 85_455
    APP_SLUG = 'cloudflare-workers-and-pages'
    PREVIEW_ROW = %r{<tr>\s*<td>\s*<strong>Preview URL:</strong>\s*</td>\s*<td>\s*<a href=['"]([^'"]+)['"]>}m

    module_function

    def live_url(github, head)
      result = github.api("repos/#{github.repository}/commits/#{head}/check-runs?per_page=100")
      checks = result.fetch('check_runs')
      latest = checks.select { |check| provider_check?(check, head) }.max_by { |check| check.fetch('id') }
      url = preview_url(latest)
      if url.nil? && result.fetch('total_count') > checks.size
        raise Error, 'Too many check runs to resolve deployment: auto; supply the URL or none.'
      end

      url
    end

    def provider_check?(check, head)
      check['head_sha'] == head && check['name'] == 'Cloudflare Pages' &&
        check.dig('app', 'id') == APP_ID && check.dig('app', 'slug') == APP_SLUG
    end

    def preview_url(check)
      return unless check && check['status'] == 'completed' && check['conclusion'] == 'success'

      url = check.dig('output', 'summary').to_s[PREVIEW_ROW, 1]
      return unless url && PublicationLinks.https_url?(url)

      url if URI.parse(url).host.end_with?('.pages.dev')
    end
  end
end
