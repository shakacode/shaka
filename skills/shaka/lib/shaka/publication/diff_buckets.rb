# frozen_string_literal: true

require_relative 'text'

module Shaka
  # Path-based counts describe the review surface, not how much effort a file took.
  module DiffBuckets
    ORDER = %w[Code Tests Docs/instructions Other].freeze
    SAFE_PATH = %r{\A[\w.@+/ -]+\z}

    module_function

    def render(pull)
      files = pull['shaka_changed_files']
      return [] unless complete?(files, pull['changed_files'])

      ordered = groups(files)
      counts = ordered.map { |name, items| "#{name} #{items.size}" }.join(' · ')
      body = ordered.map { |name, items| paths(name, items) }.join("\n\n")
      ["**Files:** #{counts}",
       "<details>\n<summary>Changed files by bucket</summary>\n\n#{body}\n\n</details>"]
    end

    def groups(files)
      grouped = files.group_by { |file| bucket(file['filename']) }
      ORDER.filter_map { |name| [name, grouped[name]] if grouped[name] }
    end

    def complete?(files, count)
      files.is_a?(Array) && files.size == count &&
        files.all? { |file| file.is_a?(Hash) && file['filename'].is_a?(String) }
    end

    def bucket(path)
      return 'Tests' if path.match?(%r{(?:\A|/)(?:tests?|spec|__tests__)(?:/|\.)|[._](?:test|spec)\.[^/]+\z}i)
      if path.match?(%r{\.(?:md|mdx|rst|txt)\z|\Adocs?/|\Askills/[^/]+/config/workflow\.yml\z}i)
        return 'Docs/instructions'
      end
      return 'Code' if path.match?(/\.(?:rb|js|jsx|ts|tsx|py|go|rs|java|kt|swift|c|cpp|h|cs|sh)\z/i)

      'Other'
    end

    # Filename text is untrusted Markdown, so unusual names are counted without embedding them.
    def paths(name, items)
      listed = items.map do |file|
        path = file['filename']
        "- #{path.match?(SAFE_PATH) ? "`#{path}`" : 'a file whose name is withheld'}"
      end
      "**#{name}:**\n\n#{listed.join("\n")}"
    end

    private_class_method :groups, :complete?, :bucket, :paths
  end
end
