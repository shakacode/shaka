# frozen_string_literal: true

require 'open3'
require 'pathname'
require 'shellwords'
require_relative '../error'

module Shaka
  class Seam
    # Validates explicit repository policy before the initializer writes anything.
    module InitializerInput
      CONTROL_TOKENS = %w[&& || ; | & > >> < <<].freeze

      private

      def command_arguments(command, name)
        raise Error, "#{name} command must be a non-empty single line" unless
          command.is_a?(String) && !command.strip.empty? && !command.match?(/[\0\r\n]/)

        arguments = Shellwords.split(command)
        raise Error, "#{name} command must be a simple argv command" if invalid_command?(arguments)

        validate_executable(arguments.first, name)
        arguments
      rescue ArgumentError => e
        raise Error, "#{name} command is invalid: #{e.message}"
      end

      def invalid_command?(arguments)
        arguments.empty? || arguments.first.include?('=') || arguments.intersect?(CONTROL_TOKENS)
      end

      def validate_executable(executable, name)
        return unless executable.include?('/')

        path = repository_file(executable, "#{name} command")
        raise Error, "#{name} command is not executable: #{executable}" unless File.executable?(path)
      end

      def base_branch
        value = required('base_branch')
        _output, status = Open3.capture2e('git', 'check-ref-format', '--branch', value)
        raise Error, 'base branch must be a valid Git branch name' unless status.success?

        value
      end

      def required(name)
        value = @options[name.to_sym]
        raise Error, "--#{name.tr('_', '-')} is required" unless value.is_a?(String) && !value.strip.empty?

        value
      end

      def required_list(key, flag)
        values = string_list(key, flag)
        raise Error, "--#{flag.tr('_', '-')} is required" if values.empty?

        values
      end

      def string_list(key, flag)
        values = @options.fetch(key, [])
        valid = values.all? { |value| value.is_a?(String) && !value.strip.empty? && !value.match?(/[\0\r\n]/) }
        raise Error, "--#{flag.tr('_', '-')} must be a non-empty single line" unless valid

        values
      end

      def repository_file(relative, label)
        path = File.expand_path(relative, @root)
        inside = !Pathname.new(relative).absolute? && path.start_with?("#{@root}/")
        raise Error, "#{label} must stay inside the repository" unless inside
        raise Error, "#{label} does not exist: #{relative}" unless File.file?(path)
        raise Error, "#{label} must resolve inside the repository" unless File.realpath(path).start_with?("#{@root}/")

        path
      end
    end
  end
end
