# frozen_string_literal: true

require_relative '../configuration/settings_preview'

module Shaka
  class Seam
    # Selecting a preview is an explicit local action, separate from checking policy.
    class PreviewCommand
      def self.run(arguments) = new(arguments).run

      def initialize(arguments)
        @arguments = arguments.dup
        @options = { root: Dir.pwd }
      end

      def run
        parser = option_parser
        parser.parse!(@arguments)
        operation = @arguments.shift
        validate_operation(operation, parser)
        preview = Configuration::SettingsPreview.new(root: @options[:root])
        puts JSON.pretty_generate(run_operation(preview, operation))
        0
      end

      private

      def run_operation(preview, operation)
        return preview.public_send(operation) unless operation == 'start'

        raise OptionParser::MissingArgument, '--ref DEFAULT_SHA is required for start' unless @options[:default_ref]

        preview.start(@options[:settings_ref], default_ref: @options[:default_ref])
      end

      def option_parser
        OptionParser.new do |flags|
          flags.banner = 'Usage: shaka seam preview start|stop|status --root DIR ' \
                         '[--settings-ref SHA] [--ref DEFAULT_SHA]'
          flags.on('--root DIR') { |value| @options[:root] = value }
          flags.on('--settings-ref SHA') { |value| @options[:settings_ref] = value }
          flags.on('--ref DEFAULT_SHA') { |value| @options[:default_ref] = value }
        end
      end

      def validate_operation(operation, parser)
        raise OptionParser::InvalidArgument, parser.to_s unless
          @arguments.empty? && %w[start stop status].include?(operation)
        raise OptionParser::InvalidArgument, '--settings-ref and --ref are only for start' if
          operation != 'start' && @options.values_at(:settings_ref, :default_ref).any?
      end
    end
  end
end
