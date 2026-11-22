# frozen_string_literal: true

require_relative '../packaged_text'

module Shaka
  class Help
    # Renders human-readable help overviews, topic cards, and top-level PR command pointers.
    module Formatter
      RELATED_TOPICS = { 'doctor' => 'setup', 'merge' => 'merging', 'review' => 'reviews',
                         'walkthrough' => 'reviews', 'configure' => 'settings', 'prompt' => 'settings',
                         'seam' => 'setup', 'companions' => 'skills', 'timings' => 'retrospective',
                         'usage' => 'retrospective' }.freeze

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

      def pr_command(name)
        lines = ["Usage: shaka #{name} OWNER/REPO NUMBER [options]"]
        lines << PackagedText.render('walkthrough-help.md').chomp if name == 'walkthrough'
        lines << "Run `shaka #{name} --help` for all options."
        related = RELATED_TOPICS[name]
        lines << "See also: shaka help #{related}" if related
        "#{lines.join("\n")}\n"
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
          '  shaka help COMMAND      Show options for a CLI command (e.g. shaka help doctor).',
          '  shaka doctor            Check this machine and repository setup.',
          '  shaka --help            List every CLI command.'
        ]
      end
    end
  end
end
