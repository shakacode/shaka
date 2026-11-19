# frozen_string_literal: true

require 'uri'
require 'open3'

module ShakaDocs
  # Public guides may cite other projects' skills, but never route readers into Shaka's agent procedures.
  module Audiences
    DOCUMENT_DIRECTORIES = %w[.agents .github contributing docs eval internal skills templates test].freeze
    # Root documents have distinct audiences: project entry, RubyGems, contributors, releases, and agents.
    ROOT_DOCUMENTS = %w[README.md README.gem.md CONTRIBUTING.md CHANGELOG.md AGENTS.md CLAUDE.md].freeze
    AGENT_ENTRY_FILES = %w[AGENTS.md CLAUDE.md SKILL.md].freeze

    module_function

    def links(text)
      text = text.gsub(/^ {0,3}(`{3,}|~{3,}).*?^ {0,3}\1[^\n]*$/m, '')
      inline = text.scan(/\]\(\s*<?([^)\s>]+)/).flatten
      defined = text.scan(/^\s{0,3}\[(?!\^)[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)/).flatten
      html = text.scan(/href\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'<>\x60=]+))/).flatten.compact
      urls = text.scan(%r{https?://[^\s<>()"'\]]+})
      (inline + defined + html + urls).uniq
    end

    def repository_path(uri)
      return unless %w[github.com www.github.com raw.githubusercontent.com].include?(uri.host.downcase)
      return unless uri.path.match?(%r{\A/shakacode/shaka/}i)

      # Refs may contain slashes. Check source URLs conservatively for agent-tree
      # segments instead of guessing which segments name the ref.
      uri.path[%r{/(?:skills|\.agents)(?:/.*)?\z}] || File.basename(uri.path)
    end

    def local_path(repository, source, target)
      uri = URI.parse(target)
      return repository_path(uri)&.delete_prefix('/') if uri.host
      return if uri.scheme
      return URI::DEFAULT_PARSER.unescape(uri.path).delete_prefix('/') if uri.path.start_with?('/')

      File.expand_path(URI::DEFAULT_PARSER.unescape(uri.path), File.dirname(source)).delete_prefix("#{repository}/")
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
      instructions = path.match?(%r{\A(?:skills|\.agents)(?:/|\z)}) &&
                     (path.match?(/\.mdx?\z/) || File.extname(path).empty?)
      instructions || AGENT_ENTRY_FILES.include?(File.basename(path))
    end

    def agent_links(repository, source, text)
      agent_targets(repository, source, links(text))
    end

    def agent_targets(repository, source, targets)
      targets.select do |target|
        path = local_path(repository, source, target)
        path && agent_path?(URI::DEFAULT_PARSER.unescape(path))
      end
    end

    def document_files(repository)
      git_directory = File.join(repository, '.git')
      return Dir.glob('**/*.{md,mdx}', File::FNM_DOTMATCH, base: repository) unless File.exist?(git_directory)

      output, error, status = Open3.capture3('git', '-C', repository, 'ls-files', '--cached', '--others',
                                             '--exclude-standard', '-z')
      raise ArgumentError, "Cannot inventory documentation: #{error}" unless status.success?

      output.split("\0").grep(/\.mdx?\z/).uniq
    end

    def unclassified_documents(repository)
      document_files(repository).reject do |path|
        DOCUMENT_DIRECTORIES.include?(path.split('/').first) || ROOT_DOCUMENTS.include?(path)
      end
    end
  end
end
