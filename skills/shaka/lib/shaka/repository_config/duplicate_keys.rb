# frozen_string_literal: true

require 'psych'
require_relative '../error'

module Shaka
  class RepositoryConfig
    # Rejects YAML where a later entry could silently replace an earlier value: duplicate, merge, or tagged keys.
    module DuplicateKeys
      STR_TAG = 'tag:yaml.org,2002:str'
      # Far beyond any real settings file, and far below the depth that overflows Psych's recursive visitors.
      MAX_DEPTH = 100

      module_function

      def check(source, filename:)
        stream = Psych.parse_stream(source, filename:)
        raise Error, "#{filename} must contain one YAML document" unless stream.children.length == 1

        root = stream.children.first.root
        check_depth(root, filename)
        visit(root)
      end

      # Walks without recursion, so the check itself cannot overflow the stack it protects.
      def check_depth(root, label)
        pending = [[root, 1]]
        until pending.empty?
          node, depth = pending.pop
          raise Error, "#{label} nests deeper than #{MAX_DEPTH} levels" if depth > MAX_DEPTH

          node.children&.each { |child| pending << [child, depth + 1] }
        end
      end

      def visit(node)
        return unless node.respond_to?(:children) && node.children
        return node.children.each { |child| visit(child) } unless node.is_a?(Psych::Nodes::Mapping)

        visit_mapping(node)
      end

      def visit_mapping(node)
        keys = node.children.each_slice(2).map do |key, value|
          check_key(key)
          visit(value)
          key.value
        end
        duplicate = keys.tally.find { |_key, count| count > 1 }&.first
        raise Error, "duplicate key: #{duplicate}" if duplicate
      end

      # Psych applies a merge key even with aliases off. It also decodes a tagged key, such as
      # !!binary PDw= for <<, before comparing it, so a tag could hide a merge or a duplicate.
      # A !!str key keeps its literal text, so it stays allowed.
      def check_key(key)
        raise Error, 'YAML keys must be strings' unless key.is_a?(Psych::Nodes::Scalar)
        raise Error, 'YAML merge keys (<<) are not allowed' if key.value == '<<'
        raise Error, "YAML keys must not carry tags other than !!str: #{key.value}" if key.tag && key.tag != STR_TAG
      end
    end
  end
end
