# frozen_string_literal: true

require_relative '../error'
require_relative 'command_paths'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the fixed command interface and returns its effective paths.
    class CommandSchema
      include Validation

      def initialize(root:, available_commands: nil)
        @root = root
        @available_commands = available_commands
      end

      def validate
        validate_names(CommandPaths::REQUIRED.keys + available_optional_commands)
      end

      def validate_available_optional_commands
        validate_names(available_optional_commands)
      end

      private

      def validate_names(names)
        validate_interface_directory
        validate_legacy_optional_paths
        validate_dependencies(names)
        names.to_h do |name|
          path = CommandPaths::ALL.fetch(name)
          executable!(path, path)
          [name, path]
        end.freeze
      end

      def validate_interface_directory
        %w[.agents .agents/bin].each do |relative|
          path = File.join(@root, relative)
          raise Error, "#{relative} must be a real directory, not a symlink" if File.symlink?(path)
        end
      end

      def available_optional_commands
        return @available_commands & CommandPaths::OPTIONAL.keys if @available_commands

        CommandPaths::OPTIONAL.keys.select do |name|
          command_entry?(CommandPaths::OPTIONAL.fetch(name))
        end
      end

      def command_entry?(relative)
        path = File.join(@root, relative)
        File.exist?(path) || File.symlink?(path)
      end

      def validate_dependencies(names)
        return unless names.include?('trigger_hosted_ci') && !names.include?('validate_local')

        trigger = CommandPaths::OPTIONAL.fetch('trigger_hosted_ci')
        local = CommandPaths::OPTIONAL.fetch('validate_local')
        raise Error, "#{trigger} requires #{local}"
      end

      def validate_legacy_optional_paths
        CommandPaths::LEGACY_OPTIONAL.each do |name, legacy_path|
          fixed_path = CommandPaths::OPTIONAL.fetch(name)
          next unless command_entry?(legacy_path) && !command_entry?(fixed_path)

          raise Error, "#{legacy_path} requires the standard entry point #{fixed_path}"
        end
      end
    end
  end
end
