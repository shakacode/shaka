# frozen_string_literal: true

module Shaka
  class Help
    # Renders human-readable help overviews and topic cards.
    module Formatter
      module_function

      def overview(catalog)
        lines = [
          'Shaka help — browse topics, example prompts, and guides.',
          'In Codex use $shaka; in Claude Code, Cursor, OpenCode, or Copilot use /shaka.'
        ]
        catalog.groups.each { |group| lines.concat(group_lines(catalog, group)) }
        lines.concat(footer_lines)
        "#{lines.join("\n")}\n"
      end

      def topic(entry)
        lines = ["#{entry.fetch('title')} (#{entry.fetch('id')})", entry.fetch('summary'), '', 'Example prompts:']
        entry.fetch('prompts').each { |prompt| lines << "  #{prompt}" }
        lines << ''
        lines << "Guide: #{entry.fetch('url')}"
        lines << "Local guide: #{local_guide(entry)}" if entry['local_doc']
        "#{lines.join("\n")}\n"
      end

      def local_guide(entry)
        entry['anchor'] ? "#{entry['local_doc']}##{entry['anchor']}" : entry['local_doc']
      end

      def group_lines(catalog, group)
        entries = catalog.topics_for(group.fetch('id')).map do |item|
          format('  %<id>-15s %<summary>s', id: item.fetch('id'), summary: item.fetch('summary'))
        end
        ['', "#{group.fetch('title')}:", *entries]
      end

      def footer_lines
        [
          '',
          'Next steps:',
          '  shaka help TOPIC        Show prompts and guide link for a topic.',
          '  shaka --help            List every CLI command and how to inspect its options.',
          '  shaka doctor            Check this machine and repository setup.'
        ]
      end
    end
  end
end
