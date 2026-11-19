# frozen_string_literal: true

require 'commonmarker'
require 'yaml'

module ShakaDocs
  # Keep publication IDs, URLs and visibility owned by the checked source paths and sidebar.
  module Metadata
    OVERRIDES = %w[id slug draft unlisted <<].freeze

    module_function

    def route_groups(files)
      files.group_by do |file|
        id = file.sub(/\.(?:md|mdx)\z/, '')
        directory = File.dirname(id)
        indexes = ['index', 'readme', File.basename(directory).downcase]
        indexes.include?(File.basename(id).downcase) ? directory : id
      end
    end

    def overrides(text)
      node = Commonmarker.parse(text, options: { extension: { front_matter_delimiter: '---' } }).first_child
      return [] unless node&.type == :frontmatter

      mapping = Psych.parse(node.literal)&.root
      return [] if empty?(mapping)
      raise ArgumentError, 'Expected a front-matter mapping' unless mapping.is_a?(Psych::Nodes::Mapping)

      mapping.children.each_slice(2).map { |key, _value| scalar_key(key) } & OVERRIDES
    end

    def empty?(node)
      node.nil? || (node.is_a?(Psych::Nodes::Scalar) && node.plain &&
                   ['', '~', 'null', 'Null', 'NULL'].include?(node.value))
    end

    def scalar_key(node)
      raise ArgumentError, 'Expected scalar front-matter keys' unless node.is_a?(Psych::Nodes::Scalar)

      node.value
    end
  end
end
