# frozen_string_literal: true

module Shaka
  # Reads a packaged skills/shaka/config/*.md text and fills its {{name}} placeholders.
  # One pass, so a value that itself contains {{name}} or a backslash is inserted unchanged.
  module PackagedText
    DIRECTORY = File.expand_path('../../config', __dir__)

    module_function

    def render(name, **values)
      File.read(File.join(DIRECTORY, name), encoding: 'UTF-8')
          .gsub(/\{\{(\w+)\}\}/) { values.fetch(Regexp.last_match(1).to_sym) }
    end
  end
end
