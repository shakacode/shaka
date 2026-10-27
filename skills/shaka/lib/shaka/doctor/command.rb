# frozen_string_literal: true

module Shaka
  class Doctor
    # Parses doctor options before any optional billable launch.
    module Command
      BANNER = 'Usage: shaka doctor [--root DIR] [--host NAME] [--brief] [--startup-review | --probe-reviewers]'

      def option_parser(options)
        OptionParser.new do |flags|
          flags.banner = BANNER
          flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
          flags.on('--host NAME', Usage::READERS.keys, Usage::READERS.keys.join(', ')) do |value|
            options[:host] = value
          end
          probe_flags(flags, options)
          mode_flags(flags, options)
          flags.on('-h', '--help', 'Show usage') { options[:help] = true }
        end
      end

      def mode_flags(flags, options)
        flags.on('--brief', 'Task-start check: installation, settings source, Ruby, gh, repository access') do
          options[:brief] = true
        end
        flags.on('--installation-json', 'JSON installation identity') { options[:installation_json] = true }
      end

      def probe_flags(flags, options)
        flags.on('--ref SHA', 'Verified default-branch commit for billable probes') { |value| options[:ref] = value }
        flags.on('--probe-reviewers', 'Launch each configured reviewer once; may consume quota or incur cost') do
          options[:probe_reviewers] = true
        end
        startup_flags(flags, options)
        flags.on('--probe-timeout-seconds N', Integer, 'Probe deadline per reviewer, 1..120s (default: 30)') do |value|
          options[:probe_timeout] = value
        end
      end

      def startup_flags(flags, options)
        flags.on('--startup-review', 'Probe selected reviewers unless review.startup_check is false') do
          options[:startup_review] = true
        end
        flags.on('--reviewer ID', 'Limit probes to this configured PROVIDER/FAMILY; repeatable') do |value|
          (options[:reviewers] ||= []) << ReviewerSelection.parse(value).values.join('/')
        end
      end

      def validate_probe_options!(options)
        validate_probe_ref!(options)
        validate_probe_modes!(options)
        validate_probe_only_flags!(options)
        return unless options.key?(:probe_timeout)

        raise OptionParser::InvalidArgument, '--probe-timeout-seconds must be 1..120' unless
          (1..120).cover?(options[:probe_timeout])
      end

      def validate_probe_modes!(options)
        if options[:startup_review] && !options[:reviewers]
          raise OptionParser::MissingArgument, '--startup-review requires --reviewer for each selected reviewer'
        end
        return unless options[:probe_reviewers] && options[:startup_review]

        raise OptionParser::InvalidArgument, '--startup-review and --probe-reviewers cannot be combined'
      end

      def validate_probe_only_flags!(options)
        return unless options.key?(:probe_timeout) || options[:ref] || options[:reviewers]
        return if options[:probe_reviewers] || options[:startup_review]

        raise OptionParser::InvalidArgument,
              "#{probe_only_flag(options)} requires --probe-reviewers or --startup-review"
      end

      def probe_only_flag(options)
        return '--reviewer' if options[:reviewers]

        options.key?(:probe_timeout) ? '--probe-timeout-seconds' : '--ref'
      end

      def validate_probe_ref!(options)
        return unless options[:probe_reviewers] || options[:startup_review]
        return if options[:ref].to_s.match?(/\A[0-9a-f]{40}(?:[0-9a-f]{24})?\z/)

        raise OptionParser::InvalidArgument, 'Reviewer probes require --ref with a verified default-branch SHA'
      end

      def probe_options(options)
        return unless options[:probe_reviewers] || options[:startup_review]

        options.slice(:ref, :reviewers).merge(timeout: options.fetch(:probe_timeout, 30),
                                              startup: options.fetch(:startup_review, false))
      end

      private :option_parser, :mode_flags, :probe_flags, :validate_probe_options!, :validate_probe_ref!, :probe_options,
              :probe_only_flag, :startup_flags, :validate_probe_modes!, :validate_probe_only_flags!
    end
  end
end
