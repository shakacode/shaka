# frozen_string_literal: true

require_relative '../error'

module Shaka
  module UiCheck
    # The uploaded captures a UI check shows, read from its Markdown.
    module Captures
      URL = %r{https://github\.com/(?:user-attachments/assets|[\w.-]+/[\w.-]+/assets/\d+)/[\w-]+}

      module_function

      def urls(body) = body.to_s.scan(URL).uniq

      # Each "PATH#ALT TEXT" names a local file for gh to upload.
      def paths(captures)
        captures.map do |capture|
          raise Error, 'Each UI check capture must be a "PATH#ALT TEXT" string.' unless capture.is_a?(String)

          path = capture.split('#', 2).first
          readable = File.file?(path) && File.readable?(path)
          raise Error, "UI check capture is not a readable file: #{path}" unless readable

          path
        end
      end
    end
  end
end
