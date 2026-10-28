# frozen_string_literal: true

require 'psych'

module Shaka
  module Evaluation
    # Inspect syntax nodes without deserializing objects or resolving aliases.
    class WorkflowPins
      REFERENCE = %r{\A(?<action>[\w.-]+/[\w.-]+(?:/[\w.-]+)*)@(?<sha>[0-9a-f]{40})\z}

      def initialize(path)
        @path = path
      end

      def read(text)
        root = parse_root(text)
        return 'UNKNOWN' unless root

        @pins = {}
        @pending = [[root, [], 0]]
        scan
      rescue Psych::Exception, EncodingError
        'UNKNOWN'
      end

      private

      def scan
        count = 0
        until @pending.empty?
          node, path, depth = @pending.pop
          count += 1
          return 'UNKNOWN' unless within_bounds?(count, depth) && visit(node, path, depth)
        end
        @pins
      end

      def within_bounds?(count, depth) = count <= 10_000 && depth <= 40

      def parse_root(text)
        documents = Psych.parse_stream(text).children
        root = documents.first&.root
        root if documents.one? && jobs?(root)
      end

      def jobs?(root)
        root.is_a?(Psych::Nodes::Mapping) && root.children.each_slice(2).any? do |key, value|
          key.is_a?(Psych::Nodes::Scalar) && key.value == 'jobs' && value.is_a?(Psych::Nodes::Mapping)
        end
      end

      def plain?(node)
        node.respond_to?(:anchor) && node.anchor.nil? && node.respond_to?(:tag) && node.tag.nil?
      end

      def visit(node, path, depth)
        return false unless plain?(node)

        case node
        when Psych::Nodes::Mapping then mapping(node, path, depth)
        when Psych::Nodes::Sequence
          node.children.each_with_index { |child, index| @pending << [child, [*path, index], depth + 1] }
          true
        when Psych::Nodes::Scalar then true
        else false
        end
      end

      def mapping(node, path, depth)
        pairs = mapping_pairs(node)
        return false unless pairs

        pairs.all? do |key, value|
          next false if key.value == 'uses' && !record?(value, path)

          @pending << [value, [*path, key.value], depth + 1]
          true
        end
      end

      def mapping_pairs(node)
        pairs = node.children.each_slice(2).to_a
        keys = pairs.map(&:first)
        return unless keys.all? { it.is_a?(Psych::Nodes::Scalar) && plain?(it) }

        pairs if keys.map(&:value).uniq.size == keys.size
      end

      def record?(value, path)
        return false unless location?(path) && value.is_a?(Psych::Nodes::Scalar) && plain?(value)

        match = REFERENCE.match(value.value)
        return false unless match && !match[:action].split('/').intersect?(%w[. ..])

        @pins["#{@path}##{[*path, 'uses'].join('/')}:#{match[:action]}"] = match[:sha]
        true
      end

      def location?(path)
        path[0] == 'jobs' && path[1].is_a?(String) && /\A[A-Za-z_][\w-]*\z/.match?(path[1]) &&
          (path.size == 2 || (path.size == 4 && path[2] == 'steps' && path[3].is_a?(Integer)))
      end
    end
  end
end
