# frozen_string_literal: true

module Shaka
  module Configuration
    # Keep invalid Git path bytes intact while matching valid paths to filesystem strings.
    module PrivateGitPaths
      module_function

      def parse(output)
        output.b.split("\0".b).map do |path|
          native = path.dup.force_encoding(Encoding.find('filesystem'))
          native.valid_encoding? ? native : path
        end
      end
    end
  end
end
