# frozen_string_literal: true

require 'uri'
require_relative '../error'
require_relative 'pages'

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

        { metadata: :ok, org: body.dig('owner', 'type') == 'Organization' }
      end

      def classify(kind, names, access, environments:, uncertain:)
        return [[], []] if names.empty?

        known, complete = known_names(kind, names, access, environments)
        split(kind, names.uniq, known, complete, uncertain)
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

      def split(kind, names, known, complete, uncertain)
        groups = { true => [], false => [] }
        names.each do |name|
          next if known.include?(name)

          groups[complete && !uncertain.include?(name)] << "#{kind}.#{name}"
        end
        [groups[true], groups[false]]
      end

      def known_names(kind, wanted, access, environments)
        lists = catalogs(kind, wanted, access, environments)
        known = lists.flat_map { |state, names| state == :ok ? names : [] }
        [known, lists.all? { |state,| %i[ok skipped].include?(state) }]
      end

      def catalogs(kind, wanted, access, environments)
        repo_state, repo_names = repo_catalog(kind)
        lists = [[repo_state, repo_names]]
        return lists if repo_state == :ok && wanted.all? { |name| repo_names.include?(name) }

        lists << org_catalog(kind, access) << environment_catalog(kind, environments)
      end

      def repo_catalog(kind)
        @pages.named("repos/#{repository}/actions/#{api_kind(kind)}", api_kind(kind))
      end

      def org_catalog(kind, access)
        return [:denied, []] if access[:metadata] == :denied
        return [:skipped, []] unless access[:org]

        @pages.named("repos/#{repository}/actions/organization-#{api_kind(kind)}", api_kind(kind))
      end

      def environment_catalog(kind, environments)
        return [:ok, []] if environments.empty?

        names = []
        environments.each do |environment|
          encoded = URI.encode_uri_component(environment)
          state, found = @pages.named("repos/#{repository}/environments/#{encoded}/#{api_kind(kind)}", api_kind(kind))
          return [state, names] unless state == :ok

          names.concat(found)
        end
        [:ok, names]
      end

      def api_kind(kind) = kind == 'secrets' ? 'secrets' : 'variables'
    end
  end
end
