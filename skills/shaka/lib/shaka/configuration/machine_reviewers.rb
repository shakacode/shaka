# frozen_string_literal: true

require 'yaml'
require_relative '../error'
require_relative '../repository_config/review_schema'
require_relative 'paths'

module Shaka
  module Configuration
    # The reviewers one machine expects to run, from ~/.agents/shaka/local-reviewers.yml. It
    # narrows setup notices and fills a model or effort the repository leaves unset; it never adds
    # a reviewer.
    class MachineReviewers
      KEYS = %w[provider model_family model effort].freeze
      FILLS = %w[model effort].freeze

      # Nil when the file is absent or no home directory is known.
      def self.load(home:)
        return if home.nil? || home.empty?

        path = File.join(home, Paths::MACHINE_REVIEWERS)
        return unless File.exist?(path)

        new(path, read(path).each_with_index.map { |entry, index| entry!(entry, "#{path} reviewers[#{index}]") })
      end

      def self.read(path)
        data = YAML.safe_load_file(path)
        raise Error, "#{path} must set version: 1" unless data.is_a?(Hash) && data['version'] == 1
        raise Error, "#{path} reviewers must be a list" unless data['reviewers'].is_a?(Array)

        data['reviewers']
      rescue Psych::Exception => e
        raise Error, "#{path} is not valid YAML: #{e.message.lines.first.strip}"
      rescue SystemCallError => e
        raise Error, "#{path} is unreadable: #{e.message}"
      end

      def self.entry!(entry, label)
        raise Error, "#{label} must be a mapping" unless entry.is_a?(Hash)

        unknown = entry.keys - KEYS
        raise Error, "#{label} has unknown key #{unknown.first}" unless unknown.empty?

        identity!(entry, label)
        settings!(entry, label)
        entry
      end

      def self.identity!(entry, label)
        %w[provider model_family].each do |key|
          next if entry[key].is_a?(String) && !entry[key].empty?

          raise Error, "#{label} #{key} must be a non-empty string"
        end
      end

      # The same checks the repository's reviewer entries get.
      def self.settings!(entry, label)
        schema = RepositoryConfig::ReviewSchema
        schema.model_name!(entry['model'], "#{label} model") if entry.key?('model')
        schema.effort_level!(entry['effort'], "#{label} effort") if entry.key?('effort')
      end

      attr_reader :path

      def initialize(path, entries)
        @path = path
        @entries = entries.to_h { |entry| [identity(entry), entry] }
        raise Error, "#{path} lists a reviewer more than once" unless @entries.size == entries.size
      end

      def identities = @entries.keys

      def listed?(identity) = @entries.key?(identity.downcase)

      # The machine values a repository entry leaves unset; the repository's own values win, and a
      # reviewer the repository does not list gets none.
      def fill(repository_entry, identity)
        return {} unless repository_entry

        @entries.fetch(identity.downcase, {}).slice(*FILLS).reject { |key, _| repository_entry.key?(key) }
      end

      private

      def identity(entry) = entry.values_at('provider', 'model_family').join('/').downcase
    end
  end
end
