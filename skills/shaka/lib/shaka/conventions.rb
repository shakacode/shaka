# frozen_string_literal: true

require 'yaml'
require_relative 'error'
require_relative 'configuration/paths'
require_relative 'repository_config/duplicate_keys'

module Shaka
  # Files a repository adds by name beside its config.yml; the packaged list owns their paths.
  module Conventions
    PATH = File.expand_path('../../config/conventions.yml', __dir__)
    DIRECTORY = File.dirname(Configuration::Paths::NEW_CONTRACT)
    FIELDS = %w[adds_to reader when absent docs].freeze
    TABLE_BEGIN = '<!-- shaka:conventions:begin -->'
    TABLE_END = '<!-- shaka:conventions:end -->'

    def self.data
      @data ||= load(File.read(PATH, encoding: 'UTF-8'))
    end

    def self.load(source)
      RepositoryConfig::DuplicateKeys.check(source, filename: 'conventions.yml')
      data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      raise Error, "Invalid #{PATH}: expected a mapping of directories" unless data.is_a?(Hash)

      data.each { |directory, entry| validate_directory!(directory, entry) }
      data.freeze
    rescue Psych::Exception => e
      raise Error, "Invalid #{PATH}: #{e.message}"
    end

    # The repository path of one listed file, such as `prompts/checkpoint.md`.
    def self.path(name)
      directory, file = name.split('/', 2)
      raise Error, "#{PATH} lists no #{name}" unless data.dig(directory, 'files', file)

      "#{DIRECTORY}/#{name}"
    end

    def self.files = data.flat_map { |directory, entry| entry['files'].keys.map { "#{DIRECTORY}/#{directory}/#{it}" } }

    def self.directories = data.keys

    def self.readme_path(directory) = "#{DIRECTORY}/#{directory}/README.md"

    # The maintainer may write around the marked table; only the table belongs to Shaka.
    def self.readme(directory)
      "# Shaka #{directory}\n\n#{data.fetch(directory).fetch('introduction')}\n#{table(directory)}\n"
    end

    def self.table(directory)
      rows = data.fetch(directory).fetch('files').map do |file, entry|
        cells = ["`#{file}`", *entry.values_at('adds_to', 'reader', 'when', 'absent'), "[Settings](#{entry['docs']})"]
        "| #{cells.join(' | ')} |"
      end
      [TABLE_BEGIN, '| File | Adds to | Read by | When | If absent | Reference |',
       '| --- | --- | --- | --- | --- | --- |', *rows, TABLE_END].join("\n")
    end

    def self.validate_directory!(directory, entry)
      valid = entry.is_a?(Hash) && entry.keys.sort == %w[files introduction] &&
              entry['introduction'].is_a?(String) && entry['files'].is_a?(Hash)
      raise Error, "Invalid #{PATH}: #{directory} needs introduction and files" unless valid

      entry['files'].each { |file, fields| validate_file!("#{directory}/#{file}", fields) }
    end

    def self.validate_file!(name, fields)
      return if fields.is_a?(Hash) && fields.keys.sort == FIELDS.sort && fields.values.all?(String)

      raise Error, "Invalid #{PATH}: #{name} needs #{FIELDS.join(', ')}"
    end
    private_class_method :validate_directory!, :validate_file!
  end
end
