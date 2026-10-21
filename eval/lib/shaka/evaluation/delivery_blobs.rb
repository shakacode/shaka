# frozen_string_literal: true

module Shaka
  module Evaluation
    # Immutable head:path expressions are variables, never interpolated query syntax.
    module DeliveryBlobs
      private

      def read_blobs(files)
        paths = files.reject { it.fetch('changeType') == 'DELETED' }.map { it.fetch('path') }
        return {} if paths.empty?

        variables = paths.each_with_index.to_h { |path, index| ["p#{index}", "#{@head}:#{path}"] }
        data = blob_data(variables)
        paths.each_with_index.to_h { |path, index| [path, normalize_blob(data.fetch("b#{index}"))] }
      end

      def blob_data(variables)
        graphql(blob_query(variables), @variables.slice('owner', 'name').merge(variables)).fetch('repository')
      end

      def blob_query(variables)
        declarations = variables.keys.map { "$#{it}: String!" }.join(', ')
        fields = variables.keys.each_with_index.map do |name, index|
          "b#{index}: object(expression: $#{name}) { __typename " \
            '... on Blob { oid isBinary isTruncated byteSize text } }'
        end.join(' ')
        "query($owner: String!, $name: String!, #{declarations}) { " \
          "repository(owner: $owner, name: $name) { #{fields} } }"
      end

      def normalize_blob(row)
        unavailable unless blob_metadata?(row)
        result = row.slice('oid', 'isBinary')
        return result if row.fetch('isBinary')

        result.merge('lines' => text_lines(row))
      end

      def blob_metadata?(row)
        row.fetch('__typename') == 'Blob' && /\A[0-9a-f]{40}\z/.match?(row.fetch('oid')) &&
          [true, false].include?(row.fetch('isBinary')) && row.fetch('isTruncated') == false
      end

      def text_lines(row)
        text = row.fetch('text')
        unavailable unless text.is_a?(String) && text.valid_encoding? && text.bytesize == row.fetch('byteSize')

        text.lines.size
      end
    end
  end
end
