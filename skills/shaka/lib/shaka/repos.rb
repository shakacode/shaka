# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require_relative 'error'
require_relative 'prefix'
require_relative 'repos/home'

module Shaka
  # Rebuildable install-local index of repository prefixes. Not an authority source.
  class Repos
    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error, Psych::Exception => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments)
      @arguments = arguments.dup
      @options = {}
    end

    def run
      parser = option_parser
      parser.parse!(@arguments)
      return help(parser) if @options[:help]

      operation = @arguments.shift
      raise OptionParser::InvalidArgument, parser.to_s unless valid?(operation)

      operation == 'add' ? add : refresh
    end

    private

    def valid?(operation)
      %w[add refresh].include?(operation) && @arguments.empty? &&
        (operation == 'refresh' || @options.key?(:root))
    end

    def add
      puts JSON.pretty_generate({ 'roots' => home.add(@options.fetch(:root)) })
      0
    end

    def refresh
      catalog = catalog_payload
      home.write_catalog(catalog)
      puts JSON.pretty_generate(catalog)
      report_duplicates(catalog.fetch('duplicate_prefixes'))
    end

    def catalog_payload
      repositories = home.roots_list.map { |root| entry(root) }.sort_by { |row| row.fetch('identity') }
      { 'version' => 1, 'repositories' => repositories, 'duplicate_prefixes' => duplicates(repositories) }
    end

    def entry(root)
      identity, url = remote_identity(root)
      display = Prefix.new(root: root).call
      { 'identity' => identity, 'url' => url, 'root' => root,
        'prefix' => display.fetch('prefix'), 'prefix_source' => display.fetch('source') }
    end

    def remote_identity(root)
      url, error, status = Open3.capture3('git', '-C', root, 'remote', 'get-url', 'origin')
      raise Error, "Cannot read origin for #{root}: #{error.strip}" unless status.success?

      identity = parse_identity(url.strip)
      [identity, canonical_url(identity, url.strip)]
    end

    def parse_identity(url)
      path = url.sub(%r{\A(?:git@|ssh://git@|https://|http://)[^/:]+[:/]}, '').sub(/\.git\z/, '')
      raise Error, "Cannot parse owner/name from origin #{url}" unless path.match?(%r{\A[^/]+/[^/]+\z})

      path
    end

    def canonical_url(identity, origin)
      origin.match?(%r{github\.com[:/]}) ? "https://github.com/#{identity}" : origin.sub(/\.git\z/, '')
    end

    def duplicates(repositories)
      repositories.group_by { |row| row.fetch('prefix') }.each_with_object({}) do |(prefix, rows), collected|
        next unless rows.length > 1

        collected[prefix] = rows.map { |row| row.fetch('identity') }
      end
    end

    def report_duplicates(duplicates)
      return 0 if duplicates.empty?

      duplicates.each { |prefix, identities| warn "shaka: duplicate repo_prefix #{prefix}: #{identities.join(', ')}" }
      1
    end

    def home
      @home ||= Home.new(File.expand_path(home_path))
    end

    def home_path
      @options.fetch(:home, ENV.fetch('SHAKA_HOME', File.join(Dir.home, '.shaka')))
    end

    def option_parser
      OptionParser.new do |flags|
        flags.banner = "Usage: shaka repos add --root DIR\n       shaka repos refresh"
        flags.on('--root DIR', 'Repository to register') { |value| @options[:root] = value }
        flags.on('--home DIR', 'Install-local Shaka home (default: $SHAKA_HOME or ~/.shaka)') do |value|
          @options[:home] = value
        end
        flags.on('-h', '--help', 'Show usage') { @options[:help] = true }
      end
    end

    def help(parser)
      puts parser
      0
    end
  end
end
