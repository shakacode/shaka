# frozen_string_literal: true

require_relative '../provenance'
require_relative 'check'

module Shaka
  class Doctor
    # Reports whether this machine has an alias fit to publish.
    #
    # Publication accepts any value matching its safe-value pattern, and a real host name
    # matches it. So this check, not the renderer, is what stands between the machine's own
    # name and every public pull request it would appear in.
    class MachineAlias
      include Check

      VARIABLE = 'SHAKA_MACHINE_ALIAS'
      HOST_NAMES = %w[HOST HOSTNAME].freeze
      GUIDANCE = "Export #{VARIABLE} as a short deliberate token such as `m5`. It appears in " \
                 "public pull requests, so do not use this machine's own name.".freeze

      def initialize(environment) = @environment = environment

      def call
        value = @environment[VARIABLE]
        return unset if value.nil? || value.empty?
        return unpublishable unless valid?(value)
        return host_name if host_name?(value)

        check('Machine alias', 'healthy', "provenance will publish #{value}")
      end

      private

      def unset
        check('Machine alias', 'degraded', "#{VARIABLE} is unset; provenance will read UNKNOWN", guidance: GUIDANCE)
      end

      def unpublishable
        check('Machine alias', 'failed', "#{VARIABLE} is set to a value publication refuses", guidance: GUIDANCE)
      end

      # Degrades rather than blocks: the value publishes, and whether to publish it is the user's.
      # The name itself stays out of the report.
      def host_name
        check('Machine alias', 'degraded', "#{VARIABLE} is this machine's own name",
              guidance: 'Publication would put your machine name in every public pull request. ' \
                        'Replace it with a short deliberate token such as `m5`.')
      end

      def host_name?(value)
        HOST_NAMES.filter_map { |name| @environment[name] }.any? { |name| name.casecmp?(value) }
      end

      def valid?(value) = ExecutionProvenance::SAFE_VALUE.match?(value)
    end
  end
end
