# frozen_string_literal: true

require 'open3'
require 'commonmarker'
require 'nokogiri'
require_relative 'source_paths'

module ShakaDocs
  # Public guides may cite other projects' skills, but never route readers into Shaka's agent procedures.
  module Audiences
    DOCUMENT_DIRECTORIES = %w[.agents .github contributing docs eval internal skills templates test].freeze
    # Root documents have distinct audiences: project entry, RubyGems, contributors, releases, and agents.
    ROOT_DOCUMENTS = %w[README.md README.gem.md CONTRIBUTING.md CHANGELOG.md AGENTS.md CLAUDE.md].freeze
    AGENT_ENTRY_FILE = /\A(?:(?:AGENTS|CLAUDE|GEMINI|SKILL)(?:\.[^.]+)*|copilot-instructions)\.mdx?\z/i
    AGENT_DIRECTORIES = %w[skills .agents .claude .codex .cursor .gemini .opencode .pi
                           .github/agents .github/instructions .github/skills].freeze
    AGENT_CONTROL_FILES = %w[.cursorrules .windsurfrules .clinerules].freeze
    AGENT_WORKFLOW = 'skills/shaka/config/workflow.yml'

    module_function

    def url(target) = SourcePaths.url(target)

    def links(text, include_html: true)
      targets = []
      document = Commonmarker.parse(text, options: { extension: { front_matter_delimiter: '---', footnotes: true } })
      document.walk do |node|
        targets << node.url if %i[link image].include?(node.type)
        targets.concat(html_links(node)) if include_html
      end
      targets.map(&:strip).uniq
    end

    def html_links(node)
      return [] unless %i[html_inline html_block].include?(node.type)

      Nokogiri::HTML5.fragment(node.literal).css('a, area').filter_map { |link| link['href'] || link['xlink:href'] }
    end

    def navigation_links(item)
      case item
      when Array then item.flat_map { |child| navigation_links(child) }
      when Hash then sidebar_links(item)
      else []
      end
    end

    def sidebar_links(item)
      case item['type']
      when 'category' then navigation_links(item.fetch('items'))
      when 'link'
        target = item.fetch('href')
        raise ArgumentError, 'Expected a string sidebar link href' unless target.is_a?(String)

        [target]
      else []
      end
    end

    def agent_path?(path)
      return true if path == 'skills/shaka/references' || path.start_with?('skills/shaka/references/')

      instructions = agent_directory?(path) && (path.match?(/\.(?:mdx?|mdc)\z/i) || File.extname(path).empty?)
      instructions || path == AGENT_WORKFLOW || agent_entry?(path)
    end

    def agent_directory?(path)
      AGENT_DIRECTORIES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
    end

    def agent_entry?(path)
      name = File.basename(path)
      AGENT_ENTRY_FILE.match?(name) || AGENT_CONTROL_FILES.include?(name.downcase)
    end

    def agent_links(repository, source, text)
      agent_targets(repository, source, links(text))
    end

    def agent_targets(repository, source, targets)
      targets.select do |target|
        path = SourcePaths.local_path(repository, source, target)
        path && agent_path?(path)
      end
    end

    def document_files(repository)
      repository_paths(repository).grep(/\.mdx?\z/i).select { |path| File.file?(File.join(repository, path)) }
    end

    def repository_paths(repository)
      files = if File.exist?(File.join(repository, '.git'))
                git_files(repository)
              else
                Dir.glob('**/*', File::FNM_DOTMATCH, base: repository)
              end
      files.uniq
    end

    def git_files(repository)
      output, error, status = Open3.capture3('git', '-C', repository, 'ls-files', '--cached', '--others',
                                             '--exclude-standard', '-z')
      raise ArgumentError, "Cannot inventory documentation: #{error}" unless status.success?

      output.split("\0")
    end

    def unclassified_documents(repository)
      document_files(repository).reject do |path|
        DOCUMENT_DIRECTORIES.include?(path.split('/').first) || ROOT_DOCUMENTS.include?(path) || agent_path?(path)
      end
    end
  end
end
