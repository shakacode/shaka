# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../error'
require_relative '../configuration'
require_relative 'points'
require_relative 'inventory'
require_relative 'resolver'

module Shaka
  module Companions
    # `shaka companions POINT|--all`: each companion skill's mode at a skill point, why that mode
    # applies, whether it is installed, and its revision. Repository packs are read only at the
    # trusted --ref; without one, no packs are read.
    class Command
      USAGE = 'Usage: shaka companions POINT|--all [--root DIR] [--ref SHA]'

      def self.run(arguments)
        options = parse(arguments)
        return 0 unless options

        puts JSON.pretty_generate(new(**options).call)
        0
      rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
        warn "shaka: #{e.message}"
        1
      end

      def self.parse(arguments)
        options = {}
        parser = option_parser(options)
        parser.parse!(arguments)
        return puts(parser) if options[:help]
        raise OptionParser::InvalidArgument, USAGE unless arguments.size == (options[:all] ? 0 : 1)

        { point: arguments.first, root: File.realpath(options.fetch(:root, Dir.pwd)), ref: options[:ref] }
      end

      def self.option_parser(options)
        OptionParser.new do |flags|
          flags.banner = USAGE
          flags.on('--all', 'Every skill point') { options[:all] = true }
          flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
          flags.on('--ref SHA', 'Trusted default-branch commit; without it no repository packs are read') do |value|
            options[:ref] = value
          end
          flags.on('-h', '--help', 'Show usage') { options[:help] = true }
        end
      end

      private_class_method :parse, :option_parser

      def initialize(point:, root:, ref:)
        @point = point
        @root = root
        @ref = ref
      end

      def call
        declared = known_points
        sha, note = trusted_commit
        inventory = Inventory.new(root: @root, sha:, points: declared)
        resolver = Resolver.new(inventory.entries, trusted: !sha.nil?)
        rows = (@point ? [@point] : declared).flat_map { |point| resolver.call(point) }
        { 'settings_ref' => sha, 'repository_packs' => note,
          'skills' => rows.map { |row| row.to_h.transform_keys(&:to_s) }, 'warnings' => inventory.warnings.uniq }
      end

      private

      def known_points
        declared = Points.all.keys
        return declared if @point.nil? || declared.include?(@point)

        raise Error, "Unknown skill point #{@point}; known: #{declared.join(', ')}"
      end

      # Only shared team settings at the trusted commit admit repository packs; individual or
      # preview settings grant no policy, so their checkout's packs are not read.
      def trusted_commit
        return [nil, 'not read: no --ref'] unless @ref

        sha = Configuration.resolve_commit(root: @root, ref: @ref, label: 'companions ref')
        kind = settings_kind(sha)
        kind == 'trusted/team' ? [sha, "read at #{sha}"] : [nil, "not read: #{kind}"]
      end

      # Settings that cannot load at the trusted commit grant no repository packs; the command
      # reports why instead of failing.
      def settings_kind(sha)
        kind = Configuration.resolve_source(root: @root, ref: sha, candidate_commands: false).last
        kind == 'trusted/team' ? kind : "settings source is #{kind}"
      rescue Error => e
        "no usable team settings at #{sha} (#{e.message.lines.first.strip})"
      end
    end
  end
end
