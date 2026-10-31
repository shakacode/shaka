# frozen_string_literal: true

require_relative '../configuration/personal_settings'

module Shaka
  class Seam
    # Pre-fills a new or interrupted private setup from the personal settings file, and says in a
    # refusal when that file may be the cause. A completed clone, a trusted repository, `--from`,
    # and `--no-personal-file` never read the file. Flags still win: the only allowed key a flag
    # also sets is the reviewer list.
    module PersonalPrefill
      private

      def blocked_message(source)
        message = "Private setup blocked (#{source.status}): #{source.blockers.join('; ')}"
        return "#{message}. This clone already has settings; change #{Configuration::Paths::CONTRACT} directly" if
          source.status == 'complete'

        "#{message}#{personal_hint if source.status == 'partial'}"
      end

      # Setup records neither the file's contents nor the skip choice, so name each possible cause.
      def personal_hint
        if @personal
          ". #{@personal.path} may have changed since the interrupted setup, or that setup skipped it; " \
            'restore the file, repeat its --no-personal-file choice, or follow private setup recovery'
        elsif @options[:no_personal_file]
          '. The interrupted setup may have used the personal settings file; rerun without --no-personal-file'
        else
          ". If the interrupted setup read ~/#{Configuration::Paths::PERSONAL_SETTINGS}, restore that file"
        end
      end

      def config_hash
        base = super
        return base unless personal

        merged = deep_merge(base, personal.values)
        flagged = base['review'].slice('local_review_agents') if @options[:local_review_agents]
        merged['review'] = merged['review'].merge(flagged) if flagged
        validate_merged!(base, merged)
        merged
      end

      def personal
        return @personal if defined?(@personal)

        @personal = (Configuration::PersonalSettings.load(home: Dir.home) if personal_eligible?)
      end

      def personal_eligible?
        return false if @options[:no_personal_file] || seeding?

        source = Configuration.private_source(root: @root, ref: @ref)
        source.trusted_source != 'present' && source.status != 'complete'
      end

      def completed(recovery)
        recovery.inspect_checkout.merge({ 'status' => 'complete', 'seeded_from' => @options[:from] }.compact,
                                        prefill_report)
      end

      def prefill_report
        return {} unless @personal

        { 'prefilled_from' => @personal.path, 'prefilled_keys' => @personal.keys }
      end

      def deep_merge(base, overlay)
        base.merge(overlay) do |_, left, right|
          left.is_a?(Hash) && right.is_a?(Hash) ? deep_merge(left, right) : right
        end
      end

      # Linked keys, such as an opening-check model needing a reviewer, are checked on the whole result.
      def validate_merged!(base, merged)
        validate_contract(merged)
      rescue Error => e
        validate_contract(base)
        raise Error, "#{@personal.path}: #{e.message}"
      end

      def validate_contract(data)
        optional = %w[validate_local trigger_hosted_ci].select { |name| @options.key?(:"#{name}_command") }
        RepositoryConfig::Schema.new(root: @root, data:, available_commands: optional,
                                     candidate_commands: false).validate
      end
    end
  end
end
