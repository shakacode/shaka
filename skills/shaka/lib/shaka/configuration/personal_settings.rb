# frozen_string_literal: true

require 'yaml'
require_relative '../error'
require_relative '../reviewer_selection'
require_relative 'paths'

module Shaka
  module Configuration
    # Preferences from ~/.agents/shaka/config.yml that pre-fill a new clone's private setup. Only
    # setup reads the file; it is never a settings source. It may set only the preference leaves
    # below, so commands, CI review jobs, merge policy, and prompt-file paths stay repository facts.
    class PersonalSettings
      ALLOWED = %w[
        review.local_review_agents review.provider_coverage review.local_review_count
        review.local_max_rounds review.startup_check
        checkpoint.enabled checkpoint.reviewer checkpoint.model checkpoint.effort
        pr_description.opening_check.enabled pr_description.opening_check.reviewer
        pr_description.opening_check.model pr_description.opening_check.effort
        pr_description.show_shaka_credit pr_description.show_human_comments pr_description.max_human_comments
        prose_limits.max_sentence_words prose_limits.max_paragraph_words prose_limits.max_description_words
        prose_limits.words_per_changed_line
        branches.name wip.include_checkout_path
      ].freeze
      REVIEWER_KEYS = %w[provider model_family model effort].freeze
      REVIEWER_IDENTITIES = %w[checkpoint.reviewer pr_description.opening_check.reviewer].freeze

      # Nil when the file is absent or no home directory is known.
      def self.load(home:)
        return if home.nil? || home.empty?

        path = File.join(home, Paths::PERSONAL_SETTINGS)
        return unless File.exist?(path)

        new(path, read(path))
      end

      def self.read(path)
        data = YAML.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: false)
        raise Error, "#{path} must set version: 1" unless data.is_a?(Hash) && data['version'] == 1

        data.except('version')
      rescue Psych::Exception => e
        raise Error, "#{path} is not valid YAML: #{e.message.lines.first.strip}"
      rescue SystemCallError => e
        raise Error, "#{path} is unreadable: #{e.message}"
      end

      attr_reader :path, :values, :keys

      def initialize(path, values)
        @path = path
        @values = values
        @keys = leaves(values, '')
        reviewer_entries!
        reviewer_identities!
      end

      private

      def leaves(data, prefix)
        data.flat_map do |key, value|
          dotted = "#{prefix}#{key}"
          next [dotted] if ALLOWED.include?(dotted)
          next leaves(value, "#{dotted}.") if value.is_a?(Hash) && ALLOWED.any? { it.start_with?("#{dotted}.") }

          raise Error, "#{path} cannot set #{dotted}: personal settings hold preferences only, " \
                       'not repository facts or prompt files'
        end
      end

      # The schema's own parse error names the value but not the key.
      def reviewer_identities!
        REVIEWER_IDENTITIES.each do |dotted|
          *sections, key = dotted.split('.')
          section = @values.dig(*sections)
          ReviewerSelection.parse(section[key]) if section.is_a?(Hash) && section.key?(key)
        rescue Error => e
          raise Error, "#{path} #{dotted}: #{e.message}"
        end
      end

      # The entry schema also accepts a prompt file, which would name a file in another repository.
      def reviewer_entries!
        entries = @values.dig('review', 'local_review_agents')
        return unless entries.is_a?(Array)

        entries.each_with_index do |entry, index|
          extra = entry.is_a?(Hash) ? entry.keys - REVIEWER_KEYS : []
          next if extra.empty?

          raise Error, "#{path} cannot set review.local_review_agents[#{index}].#{extra.first}: " \
                       "reviewer entries may name only #{REVIEWER_KEYS.join(', ')}"
        end
      end
    end
  end
end
