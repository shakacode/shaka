# frozen_string_literal: true

require 'json'

module Shaka
  # Counts the shell commands a Codex reviewer ran, from its `--json` events. A read-only sandbox
  # that cannot start, as in a container without unprivileged user namespaces, fails every command
  # while the reviewer still answers from the diff in its prompt.
  module LocalReviewCodexCommands
    module_function

    # nil when the reviewer ran no command, because reading only the prompt can be its choice.
    def summary(stdout)
      commands = stdout.to_s.each_line.filter_map { |line| command(line) }
      return if commands.empty?

      { 'ran' => commands.size, 'succeeded' => commands.count { |item| item['status'] == 'completed' } }
    end

    def command(line)
      event = JSON.parse(line)
      item = event['item'] if event.is_a?(Hash) && event['type'] == 'item.completed'
      item if item.is_a?(Hash) && item['type'] == 'command_execution'
    rescue JSON::ParserError
      nil
    end

    private_class_method :command
  end
end
