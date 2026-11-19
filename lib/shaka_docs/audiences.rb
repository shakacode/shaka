# frozen_string_literal: true

require 'commonmarker'
require 'nokogiri'
require_relative 'source_paths'
require_relative 'inventory'

module ShakaDocs
  # Public guides may cite other projects' skills, but never route readers into Shaka's agent procedures.
  module Audiences
    DOCUMENT_DIRECTORIES = %w[.agents .github contributing docs eval internal skills templates test].freeze
    # Root documents have distinct audiences: project entry, RubyGems, contributors, releases, and agents.
    ROOT_DOCUMENTS = %w[README.md README.gem.md CONTRIBUTING.md CHANGELOG.md AGENTS.md CLAUDE.md].freeze
    AGENT_ENTRY_FILE = /\A(?:(?:AGENTS|CLAUDE|GEMINI|SKILL)(?:\.[^.]+)*|copilot-instructions)\.mdx?\z/i
    HUMAN_TOOL_GUIDE = %r{\Adocs/(?:.*/)?(?:agents|claude|gemini|skill)\.mdx?\z}
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
        targets << markdown_url(node.url) if %i[link image].include?(node.type)
        targets.concat(html_links(node)) if include_html
      end
      targets.map(&:strip).uniq
    end

    def markdown_url(target)
      target.gsub(/[\x00-\x20\\]/) { |character| format('%%%02X', character.ord) }
    end

    def html_links(node)
      return [] unless %i[html_inline html_block].include?(node.type)

      Nokogiri::HTML5.fragment(node.literal).css('a, area, form, button, input').filter_map do |link|
        link['href'] || link['xlink:href'] || link['action'] || link['formaction']
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
      return false if HUMAN_TOOL_GUIDE.match?(path)

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
      Inventory.files(repository, /\.mdx?\z/i)
    end

    def unclassified_documents(repository)
      document_files(repository).reject do |path|
        DOCUMENT_DIRECTORIES.include?(path.split('/').first) || ROOT_DOCUMENTS.include?(path) || agent_path?(path)
      end
    end
  end
end
