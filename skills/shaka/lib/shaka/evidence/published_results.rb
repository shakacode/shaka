# frozen_string_literal: true

require_relative '../publication/managed_region'
require_relative '../publication/verification_gates'
require_relative 'result'

module Shaka
  module Evidence
    # The results a description already shows for its head. Only `description` reads this, to
    # repeat that text; `evidence bind` and `evidence verify` still compare the results themselves.
    module PublishedResults
      module_function

      # A fork's author can edit its description, so only a same-repository one counts.
      def read(pull, repository)
        return unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(repository)

        region = Publishing.managed_region(pull['body'])
        head = pull.dig('head', 'sha').to_s
        line = region && region[verified_line(head[0, 7])]
        line && { 'status' => 'kept', 'head' => head, 'kept_line' => line,
                  'kept_gaps' => region[/^#{Regexp.escape(VerificationGates::GAPS)} .+$/o] }
      end

      def settings_drift?(verdict)
        return false if verdict['status'] == 'ready'

        verdict['checks'].values.flatten.reject { |entry| entry['status'] == 'bound' }.all? do |entry|
          entry['reasons'].all? { |reason| reason.match?(Result::SETTINGS_DRIFT) }
        end
      end

      def verified_line(short_head)
        /^#{Regexp.escape(VerificationGates::LABEL)} (?!UNKNOWN).* at `#{Regexp.escape(short_head)}`\./
      end
      private_class_method :verified_line
    end
  end
end
