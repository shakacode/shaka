# frozen_string_literal: true

require 'yaml'
require_relative '../error'

module Shaka
  class Help
    # Loads the packaged topic catalog and resolves topic IDs, aliases, and local installed docs.
    class Catalog
      PATH = File.expand_path('../../../config/help-topics.yml', __dir__)
      SOURCE_ROOT = File.expand_path('../../../../..', __dir__)
      DOCS_PREFIX = 'https://github.com/shakacode/shaka/blob/main/'

      def self.load(path: PATH, source_root: SOURCE_ROOT)
        data = YAML.safe_load_file(path)
        new(groups: data.fetch('groups'), topics: data.fetch('topics'), source_root:)
      end

      attr_reader :groups, :topics

      def initialize(groups:, topics:, source_root: SOURCE_ROOT)
        @groups = groups
        @source_root = source_root
        @topics = topics.map { |topic| enrich(topic) }
      end

      def find(name)
        key = name.to_s.strip.downcase
        @topics.find { |topic| topic['id'] == key || topic['aliases'].include?(key) }
      end

      def topics_for(group_id)
        @topics.select { |topic| topic['group'] == group_id }
      end

      def to_h
        { 'groups' => @groups, 'topics' => @topics }
      end

      private

      def enrich(topic)
        doc = relative_doc(topic.fetch('url'))
        topic.merge('aliases' => Array(topic['aliases']).map(&:downcase),
                    'doc' => doc,
                    'local_doc' => local_doc(doc))
      end

      def relative_doc(url)
        url.delete_prefix(DOCS_PREFIX).split('#', 2).first
      end

      def local_doc(doc)
        return unless doc.start_with?('docs/')

        path = File.join(@source_root, doc)
        path if File.file?(path)
      end
    end
  end
end
