# frozen_string_literal: true

require_relative '../error'
require_relative '../configuration/layout'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the fixed command interface and returns its effective paths.
    class CommandSchema
      include Validation

      LAYOUT = Configuration::Layout::CURRENT

      def initialize(root:, available_commands: nil, candidate_commands: true)
        @root = root
        @available_commands = available_commands
        @candidate_commands = candidate_commands
      end

      def validate
        commands = validate_names(LAYOUT.required.keys + available_optional_commands)
        validate_candidate_optional_commands
        commands
      end

      def validate_available_optional_commands
        validate_names(available_optional_commands)
      end

      private

      def validate_names(names)
        return trusted_names(names) unless @candidate_commands

        validate_interface_directory
        validate_dependencies(names)
        names.to_h do |name|
          path = LAYOUT.commands.fetch(name)
          executable!(path, path)
          [name, path]
        end.freeze
      end

      def trusted_names(names)
        validate_dependencies(names)
        trusted_commands(names)
      end

      def trusted_commands(names)
        names.to_h { |name| [name, LAYOUT.commands.fetch(name)] }.freeze
      end

      def validate_interface_directory
        [Configuration::Paths::DIRECTORY, File.dirname(LAYOUT.contract),
         LAYOUT.command_directory].uniq.each do |relative|
          path = File.join(@root, relative)
          raise Error, "#{relative} must be a real directory, not a symlink" if File.symlink?(path)
        end
      end

      def available_optional_commands
        return @available_commands & LAYOUT.optional.keys if @available_commands

        LAYOUT.optional.keys.select do |name|
          command_entry?(LAYOUT.optional.fetch(name))
        end
      end

      def validate_candidate_optional_commands
        return unless @candidate_commands && @available_commands

        names = LAYOUT.optional.filter_map { |name, path| name if command_entry?(path) }
        validate_dependencies(names)
        names.each do |name|
          path = LAYOUT.optional.fetch(name)
          executable!(path, path)
        end
      end

      def command_entry?(relative)
        path = File.join(@root, relative)
        File.exist?(path) || File.symlink?(path)
      end

      def validate_dependencies(names)
        return unless names.include?('trigger_hosted_ci') && !names.include?('validate_local')

        trigger = LAYOUT.optional.fetch('trigger_hosted_ci')
        local = LAYOUT.optional.fetch('validate_local')
        raise Error, "#{trigger} requires #{local}"
      end
    end
  end
end
