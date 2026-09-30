# frozen_string_literal: true

module Shaka
  class WorkflowConfiguration
    # Collects static secrets.NAME and vars.NAME references. secrets.GITHUB_TOKEN is provided by GitHub.
    module References
      PATTERN = /(?<!\w)(secrets|vars)\.([A-Za-z_][A-Za-z0-9_]*)/
      TOKEN = 'GITHUB_TOKEN'

      module_function

      def collect(text)
        found = { 'secrets' => [], 'vars' => [] }
        text.to_s.scan(PATTERN) do |kind, name|
          next if kind == 'secrets' && name == TOKEN

          found[kind] << name
        end
        found.transform_values { |names| names.uniq.sort }
      end
    end
  end
end
