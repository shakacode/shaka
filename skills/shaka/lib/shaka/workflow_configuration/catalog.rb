# frozen_string_literal: true

require 'uri'
require_relative '../error'
require_relative 'pages'
require_relative 'verdict'

module Shaka
  class WorkflowConfiguration
    # Reads changed workflow files and the secret and variable names a repository can see.
    class Catalog
      WORKFLOW = %r{\A\.github/workflows/[^/]+\.ya?ml\z}
      HEAD_REPOSITORY = %r{\A[\w.-]+/[\w.-]+\z}

      def initialize(github)
        @github = github
        @pages = Pages.new(github)
      end

      def repository = @github.repository

      def workflow_paths
        state, rows = @pages.list("repos/#{repository}/pulls/#{@github.number}/files")
        return [state, []] unless state == :ok

        [:ok, rows.filter_map { |row| workflow_path(row) }]
      end

      def read_workflows(paths, sha, repository)
        texts = []
        unreadable = []
        paths.each do |path|
          text = workflow_text(repository, path, sha)
          text.is_a?(String) ? texts << text : unreadable << path
        end
        [texts, unreadable]
      end

      def repository_access
        body = @pages.object("repos/#{repository}")
        return { metadata: :denied, org: false, private: nil } if body == :denied
        raise Error, 'GitHub repository metadata is malformed.' unless body.is_a?(Hash)

        { metadata: :ok, org: body.dig('owner', 'type') == 'Organization', private: privacy(body['private']) }
      end

      def classify(kind, names, access)
        return [[], []] if names.empty?

        state, found = repo_catalog(kind)
        rest = names.reject { |name| state == :ok && found.include?(name) }
        return [[], []] if rest.empty?

        org_state, entries = org_catalog(kind, access)
        Verdict.new(kind, self).divide(rest, repo_state: state, org_state:, entries:, access:)
      end

      def visible(entry, access, kind)
        case entry['visibility']
        when 'all' then true
        when 'private' then privacy(access[:private])
        when 'selected' then selected_repository(entry['name'], kind)
        end
      end

      private

      def workflow_path(row)
        return unless row.is_a?(Hash) && row['filename'].is_a?(String) && row['filename'].match?(WORKFLOW)
        return if row['status'] == 'removed'

        row['filename']
      end

      def workflow_text(repository, path, sha)
        encoded = path.split('/').map { |part| URI.encode_uri_component(part) }.join('/')
        body = @pages.content("repos/#{repository}/contents/#{encoded}?ref=#{sha}")
        return body if %i[denied unreadable].include?(body)

        @pages.decode_text(body)
      end

      def repo_catalog(kind)
        @pages.named("repos/#{repository}/actions/#{api_kind(kind)}", api_kind(kind))
      end

      def org_catalog(kind, access)
        return [:denied, []] if access[:metadata] == :denied
        return [:skipped, []] unless access[:org]

        @pages.org_entries("orgs/#{owner}/actions/#{api_kind(kind)}", api_kind(kind))
      end

      def selected_repository(name, kind)
        path = "orgs/#{owner}/actions/#{api_kind(kind)}/#{URI.encode_uri_component(name)}/repositories"
        names = @pages.repositories(path)
        return nil unless names

        names.any? { |full_name| full_name.casecmp?(repository) }
      end

      def privacy(value)
        return value if [true, false].include?(value)

        nil
      end

      def api_kind(kind) = kind == 'secrets' ? 'secrets' : 'variables'
      def owner = repository.split('/', 2).first
    end
  end
end
