# frozen_string_literal: true

require 'optparse'
require_relative 'official'
require_relative 'session_hook'
require_relative 'repair'
require_relative 'status'

module Shaka
  module Install
    # One entry point for the official checkout.
    class Command
      include StatusFlags
      include RepairFlags

      VALUES = { '--directory DIR' => :directory, '--repository URL' => :repository,
                 '--branch NAME' => :branch, '--release VERSION' => :release, '--skills-dir DIR' => :skills_dir }.freeze

      def initialize(source, program: 'bin/install', packaged_release: nil)
        @source = source
        @program = program
        @options = { agents: [], names: ['shaka'] }
        @actions = []
        @packaged_release = packaged_release
      end

      def run(arguments)
        parser.parse!(arguments)
        validate(arguments)
        perform ? 0 : 1
      rescue OptionParser::ParseError, SystemCallError, IOError, ArgumentError => e
        warn e.message
        1
      end

      private

      def parser
        OptionParser.new do |options|
          options.banner = "Usage: #{@program} [--directory DIR] [--agent NAME] " \
                           '[--update|--verify|--repair|--status [--json]]'
          VALUES.each { |flag, key| options.on(flag) { |value| @options[key] = value } }
          selections(options)
          actions(options)
        end
      end

      def selections(options)
        options.on('--agent NAME', 'codex, claude, cursor, or opencode; repeat for several') do |value|
          @options[:agents] << value
        end
        options.on('--with-mct') { @options[:names] << 'mct' }
        options.on('--with-rct') { @options[:names] << 'rct' }
        options.on('--with-claude-towers') { @options[:names].push('mct-claude', 'rct-claude') }
        options.on('--session-hook', 'Show saved update checks in new Claude chats') { @options[:session_hook] = true }
      end

      def actions(options)
        %i[update verify].each { |action| options.on("--#{action}") { @actions << action } }
        status_options(options)
        repair_options(options)
        options.on('--take-over', 'Move every host link from the checkout that owns them to this one') do
          @options[:take_over] = true
        end
        options.on('-h', '--help') do
          puts options
          exit
        end
      end

      def validate(arguments)
        raise OptionParser::InvalidArgument, arguments.join(' ') unless arguments.empty?
        raise ArgumentError, 'Choose only one of --update, --verify, --repair, and --status' if @actions.size > 1

        VALUES.each_value do |key|
          raise ArgumentError, "#{key} must not be empty" if @options[key]&.strip == ''
        end
        validate_agents
        validate_action
        validate_take_over
        validate_release
      end

      def validate_release
        raise ArgumentError, 'Choose --branch or --release, not both' if @options[:branch] && @options[:release]
        return unless @options[:release] && !@options[:release].match?(ReleaseCheckout::VERSION)

        raise ArgumentError, 'Release must be a version such as 1.0.0.rc.1'
      end

      def validate_agents
        both = @options[:skills_dir] && @options[:agents].any?
        raise ArgumentError, 'Choose --skills-dir or --agent, not both' if both

        @options[:agents].each do |agent|
          raise ArgumentError, "Unknown coding agent: #{agent}" unless Official::HOSTS.key?(agent)
        end
        SessionHook.validate(@options)
      end

      def validate_action
        validate_status
        selected = @options[:agents].any? || @options.values_at(:skills_dir, :repository, :branch, :release).any?
        return if @actions.empty? || !(selected || @options[:names] != ['shaka'])

        raise ArgumentError, 'Use bin/install to change installation selections before maintenance'
      end

      def validate_take_over
        return if !@options[:take_over] ||
                  (@actions.empty? && @options[:agents].empty? && @options[:names] == ['shaka'])

        raise ArgumentError, 'Use --take-over alone or with --directory, --repository, --branch, or --skills-dir'
      end

      def install
        select_packaged_release
        SessionHook.around(@options, @actions.any?) { Official.new(@source, @options).run(@actions[0] || :install) }
      end

      def select_packaged_release
        return unless @packaged_release && @actions.empty? && !@options[:take_over]
        return if @options.values_at(:repository, :branch, :release).any?

        directory = @options[:directory] || File.join(Dir.home, Locations::SOURCE)
        @options[:release] = @packaged_release unless File.exist?(File.join(directory, '.git', Checkout::RECORD))
      end
    end
  end
end
