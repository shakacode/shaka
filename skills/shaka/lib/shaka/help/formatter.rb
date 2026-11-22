# frozen_string_literal: true

require_relative '../packaged_text'

module Shaka
  class Help
    # Renders human-readable help overviews, topic cards, and CLI command pointers.
    module Formatter
      RELATED_TOPICS = { 'doctor' => 'setup', 'install' => 'setup', 'merge' => 'merging',
                         'review' => 'reviews', 'walkthrough' => 'reviews', 'configure' => 'settings',
                         'prompt' => 'settings', 'seam' => 'setup', 'companions' => 'skills',
                         'timings' => 'retrospective', 'usage' => 'retrospective' }.freeze

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

      def command_pointer(name, operation: nil, operations: [])
        command = ['shaka', name, operation].compact.join(' ')
        lines = ["`#{command}` is a CLI command. Run `#{help_target(command, operation, operations)} --help` " \
                 'for its options.']
        lines << "Operations: #{operations.join(', ')}" if operation.nil? && !operations.empty?
        lines << PackagedText.render('walkthrough-help.md').chomp if name == 'walkthrough'
        lines << "Related topic: shaka help #{RELATED_TOPICS[name]}" if RELATED_TOPICS.key?(name)
        "#{lines.join("\n")}\n"
      end

      def help_target(command, operation, operations)
        operation.nil? && !operations.empty? ? "#{command} <operation>" : command
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
          '  shaka COMMAND --help    Show options for a CLI command (e.g. shaka doctor --help).',
          '  shaka doctor            Check this machine and repository setup.',
          '  shaka --help            List every CLI command.'
        ]
      end
    end
  end
end
