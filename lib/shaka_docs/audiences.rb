# frozen_string_literal: true

require 'uri'

module ShakaDocs
  # Public guides may cite other projects' skills, but never route readers into Shaka's agent procedures.
  module Audiences
    DOCUMENT_DIRECTORIES = %w[.agents .github contributing docs eval internal skills templates test].freeze
    # Root documents have distinct audiences: project entry, RubyGems, contributors, releases, and agents.
    ROOT_DOCUMENTS = %w[README.md README.gem.md CONTRIBUTING.md CHANGELOG.md AGENTS.md CLAUDE.md].freeze

    module_function

    def links(text)
      inline = text.scan(/\]\(\s*<?([^)\s>]+)/).flatten
      defined = text.scan(/^\s{0,3}\[(?!\^)[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)/).flatten
      html = text.scan(/href\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'<>\x60=]+))/).flatten.compact
      urls = text.scan(%r{https?://[^\s<>()"'\]]+})
      (inline + defined + html + urls).uniq
    end

    def repository_path(uri)
      prefix = case uri.host
               when 'github.com' then %r{\A/shakacode/shaka/(?:blob|tree)/[^/]+/}
               when 'raw.githubusercontent.com' then %r{\A/shakacode/shaka/[^/]+/}
               end
      uri.path.sub(prefix, '') if prefix && uri.path.match?(prefix)
    end

    def target_path(uri)
      return repository_path(uri) if uri.host
      return if uri.scheme

      uri.path
    end

    def local_path(repository, source, target)
      uri = URI.parse(target)
      path = target_path(uri)
      return if path.nil? || path.empty?

      directory = uri.host || path.start_with?('/') ? repository : File.dirname(source)
      destination = File.expand_path(URI::DEFAULT_PARSER.unescape(path).delete_prefix('/'), directory)
      destination if destination.start_with?("#{repository}/")
    rescue URI::InvalidURIError
      nil
    end

    def navigation_links(item)
      case item
      when Array then item.flat_map { |child| navigation_links(child) }
      when Hash then [item['href'], *item.values.flat_map { |child| navigation_links(child) }].compact
      else []
      end
    end

    def agent_path?(path)
      path.match?(%r{(?:\A|/)(?:skills/.*\.mdx?(?:\z|/)|skills/[^/]+/references(?:/|\z)|\.agents/.*\.mdx?\z)}) ||
        File.basename(path).match?(/\A(?:AGENTS|CLAUDE|SKILL)\.md\z/i)
    end

    def agent_links(repository, source, text)
      links(text).select do |target|
        path = local_path(repository, source, target)
        path && agent_path?(path.delete_prefix("#{repository}/"))
      end
    end

    def unclassified_documents(repository)
      Dir.glob('**/*.{md,mdx}', File::FNM_DOTMATCH, base: repository).reject do |path|
        DOCUMENT_DIRECTORIES.include?(path.split('/').first) || ROOT_DOCUMENTS.include?(path)
      end
    end
  end
end
