# frozen_string_literal: true

require 'uri'
require 'open3'
require 'commonmarker'
require 'nokogiri'

module ShakaDocs
  # Public guides may cite other projects' skills, but never route readers into Shaka's agent procedures.
  module Audiences
    DOCUMENT_DIRECTORIES = %w[.agents .github contributing docs eval internal skills templates test].freeze
    # Root documents have distinct audiences: project entry, RubyGems, contributors, releases, and agents.
    ROOT_DOCUMENTS = %w[README.md README.gem.md CONTRIBUTING.md CHANGELOG.md AGENTS.md CLAUDE.md].freeze
    AGENT_ENTRY_FILES = %w[AGENTS.md CLAUDE.md SKILL.md].freeze
    AGENT_WORKFLOW = 'skills/shaka/config/workflow.yml'
    SOURCE_URL = %r{
      \A(?:https?:)?//(?:www\.)?(?:github\.com|raw\.githubusercontent\.com)
      (?::\d+)?/shakacode/shaka/
    }ix

    module_function

    def links(text)
      targets = []
      Commonmarker.parse(text, options: { extension: { front_matter_delimiter: '---' } }).walk do |node|
        targets << node.url if node.type == :link
        next unless %i[html_inline html_block].include?(node.type)

        targets.concat(Nokogiri::HTML.fragment(node.literal).css('a[href]').map { |link| link['href'] })
      end
      targets.uniq
    end

    def repository_path(target)
      return unless target.match?(SOURCE_URL)

      # Source citations use a commit, tag, or single-segment branch. Do not infer
      # a repository root from a directory name inside the document path.
      source = target.sub(SOURCE_URL, '').sub(%r{\A(?:blob|tree|raw|edit|blame)/}, '')
      source.sub(%r{\Arefs/(?:heads|tags)/}, '').split('/', 2).last
    end

    def local_path(repository, source, target)
      target = URI::DEFAULT_PARSER.unescape(target.sub(/[?#].*/, ''))
      if target.match?(%r{\A(?:[a-z][\w+.-]*:|//)}i)
        path = repository_path(target)
        return File.expand_path(path, '/').delete_prefix('/') if path

        return
      end
      return "docs#{target}" if target.start_with?('/')

      File.expand_path(target, File.dirname(source)).delete_prefix("#{repository}/")
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
      instructions || path == AGENT_WORKFLOW || AGENT_ENTRY_FILES.include?(File.basename(path))
    end

    def agent_links(repository, source, text)
      agent_targets(repository, source, links(text))
    end

    def agent_targets(repository, source, targets)
      targets.select do |target|
        path = local_path(repository, source, target)
        path && agent_path?(path)
      end
    end

    def document_files(repository)
      git_directory = File.join(repository, '.git')
      return Dir.glob('**/*.{md,mdx}', File::FNM_DOTMATCH, base: repository) unless File.exist?(git_directory)

      output, error, status = Open3.capture3('git', '-C', repository, 'ls-files', '--cached', '--others',
                                             '--exclude-standard', '-z')
      raise ArgumentError, "Cannot inventory documentation: #{error}" unless status.success?

      output.split("\0").grep(/\.mdx?\z/).uniq.select { |path| File.file?(File.join(repository, path)) }
    end

    def unclassified_documents(repository)
      document_files(repository).reject do |path|
        DOCUMENT_DIRECTORIES.include?(path.split('/').first) || ROOT_DOCUMENTS.include?(path)
      end
    end
  end
end
