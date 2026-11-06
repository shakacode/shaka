# frozen_string_literal: true

require 'digest'
require 'yaml'
require_relative '../gitlab'
require_relative '../configuration/paths'
require_relative '../repository_config/duplicate_keys'
require_relative 'actor_trust'

module Shaka
  class GitLab
    # Native actor IDs come only from the verified default branch, never the MR branch.
    class TrustConfig
      PATH = Configuration::Paths::GITLAB_REPOSITORY_ALLOWLIST
      MAX_BYTES = 65_536
      ACTORS = { users: 'trusted_users', bots: 'trusted_bots', metadata_bots: 'trusted_metadata_bots' }.freeze

      def initialize(client:)
        @client = client
      end

      def load
        revision = @client.default_revision
        text = read_text(revision)
        settings = text.nil? ? ACTORS.transform_values { [] } : parse_settings(text)
        unless revision == @client.default_revision
          raise Error, 'GitLab trusted default revision changed during the read.'
        end

        settings.merge(sources: [provenance(revision, text)])
      end

      private

      def read_text(revision)
        file = @client.api("projects/#{revision.fetch('id')}/repository/files/#{URI.encode_www_form_component(PATH)}",
                           fields: { ref: revision.fetch('sha') })
        trusted_text(file, revision)
      rescue Error => e
        raise unless e.http_status == 404

        nil
      end

      def parse_settings(text)
        data = settings_data(text)
        settings = ACTORS.transform_values { |key| actor_pairs(data.fetch(key, [])) }
        ids = settings.values.flatten.map { |pair| pair.fetch('id') }
        raise Error, 'GitLab actor settings contain duplicate or conflicting IDs.' unless ids.uniq == ids

        settings
      end

      def settings_data(text)
        RepositoryConfig::DuplicateKeys.check(text, filename: PATH)
        data = YAML.safe_load(text, aliases: false)
        data = {} if data.nil?
        unless data.is_a?(Hash) && (data.keys - ACTORS.values).empty?
          raise Error, 'GitLab actor settings must contain only native actor lists.'
        end

        data
      rescue Psych::Exception
        raise Error, 'GitLab actor settings contain malformed or unsafe YAML.'
      end

      def actor_pairs(values)
        raise Error, 'GitLab actor settings must be lists.' unless values.is_a?(Array)

        values.map do |pair|
          unless pair.is_a?(Hash) && pair.keys.all?(String) && pair.keys.sort == %w[id username]
            raise Error, 'GitLab configured actors need only their native ID and username.'
          end

          ActorTrust::Input.identity(pair)
        end
      end

      def trusted_text(file, revision)
        validate_file(file, revision)
        text = file['content'].delete("\r\n").unpack1('m0').force_encoding(Encoding::UTF_8)
        unless text.valid_encoding? && text.bytesize == file['size'] &&
               Digest::SHA256.hexdigest(text) == file['content_sha256']
          raise Error, 'GitLab trusted actor file content failed verification.'
        end

        text
      rescue ArgumentError
        raise Error, 'GitLab trusted actor file encoding is invalid.'
      end

      def validate_file(file, revision)
        sha = revision.fetch('sha')
        metadata = file.values_at('file_path', 'ref', 'commit_id', 'encoding') == [PATH, sha, sha, 'base64']
        size = file['size']
        content = file['content']
        unless metadata && size.is_a?(Integer) && (0..MAX_BYTES).cover?(size) &&
               content.is_a?(String) && content.ascii_only? && content.bytesize <= MAX_BYTES * 2
          raise Error, 'GitLab trusted actor file metadata is unavailable or mismatched.'
        end
      end

      def provenance(revision, text)
        { 'scope' => 'repository', 'provider' => 'gitlab', 'host' => revision.fetch('host'),
          'project_id' => revision.fetch('id'), 'repository' => revision.fetch('path_with_namespace'),
          'commit' => revision.fetch('sha'), 'path' => PATH, 'state' => text.nil? ? 'absent' : 'present',
          'sha256' => text && Digest::SHA256.hexdigest(text) }
      end
    end
  end
end
