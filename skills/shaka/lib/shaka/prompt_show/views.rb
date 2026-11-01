# frozen_string_literal: true

require 'securerandom'
require_relative '../local_review/runner'
require_relative '../opening_publication'
require_relative '../post_implementation_runner'
require_relative '../prompt_section'

module Shaka
  module PromptShow
    # Runs a reviewer's own prompt assembly, swapping change data the reviewer would receive for placeholders.
    # Without a change, only the root AGENTS.md is shown and nested ones are listed with the directory that adds them.
    module View
      attr_reader :notes

      def sections
        validate_path!
        git_executable
        resolve_change!
        prepare!
        @notes = []
        @disabled ? nil : prompt_sections(SecureRandom.hex(16))
      end

      private

      # A draft is read from the working tree, so a settings preview must not redirect it.
      def settings_ref = @options[:draft] ? @options[:criteria_ref] : super

      def resolve_change!
        @change = @options.key?(:head)
        return @options.merge!(head: '<HEAD>', base: '<BASE>') unless @change

        %i[head base].each { |key| @options[key] = commit(key) }
      end

      def commit(key)
        capture(git_executable, '-C', root, 'rev-parse', '--verify', '--quiet', '--end-of-options',
                "#{@options[key]}^{commit}").strip
      rescue LocalReviewPathGuard::CommandFailed
        raise Error, "--#{key} #{@options[key]} is not a commit in this checkout"
      end

      def applicable_criteria(entries)
        return super if @change

        entries.keys.select { |file| file == 'AGENTS.md' }.map { |file| resolved_criteria(entries, file) }
      end

      def trusted_criteria(marker)
        sections = super
        list_nested_criteria unless @change || !@options[:criteria_ref]
        sections
      end

      def list_nested_criteria
        nested = trusted_tree(@options[:criteria_ref]).keys.grep(%r{/AGENTS\.md\z}).sort
        @notes += nested.map { |file| "#{file} is added when a change touches #{File.dirname(file)}/" }
      end

      def diff_section(marker)
        placeholder("diff #{@options[:base]}...#{head}", 'DIFF DATA', marker, '')
      end

      def placeholder(what, block, marker, ending = "\n")
        PromptSection.new("placeholder: #{what}",
                          "--- BEGIN #{block} #{marker} ---\n<#{what}>\n--- END #{block} #{marker} ---\n#{ending}")
      end
    end

    # The code review prompt for one reviewer.
    class ReviewView < LocalReviewRunner
      include View

      private

      def prepare!
        @options[:reviewer] = (@options[:reviewer] || default_reviewer).then do |identity|
          ReviewerSelection.parse(identity).values.map(&:downcase).join('/')
        end
        raise Error, 'Unsupported local reviewer' unless ReviewerSelection::SUPPORTED_REVIEWERS.include?(reviewer)

        apply_trusted_settings!
      end

      # The first reviewer the settings list, as `shaka reviewer` would try it.
      def default_reviewer
        agents = Array((effective_review || {})[RepositoryConfig::ReviewSchema::LOCAL_REVIEW_AGENTS]).grep(Hash)
        identity = agents.first&.values_at(*ReviewerSelection::IDENTITY)&.join('/')
        identity || raise(Error, 'The settings list no local reviewer; pass --reviewer PROVIDER/FAMILY')
      end

      def description_section(marker)
        [placeholder('PR description, sent only when review run gets --description-file', 'PR DESCRIPTION DATA',
                     marker)]
      end

      def prior_rounds_section(_marker)
        [PromptSection.new('placeholder: earlier rounds, sent only when the review ledger has them',
                           "<PRIOR ROUNDS instructions with each earlier finding's class and disposition>\n\n")]
      end
    end

    # The product checkpoint prompt with the reviewer its settings choose.
    class CheckpointView < PostImplementationRunner
      include View

      private

      def prepare!
        raise Error, '--ref or --local is required' unless @options[:criteria_ref]

        validate_reviewer!
      end

      def packet_section(marker) = placeholder('checkpoint packet from --content-file', 'PACKET DATA', marker, '')
    end

    # The opening check prompt, read through the same settings path as description publication.
    class OpeningView
      OPENING = 'first paragraph of the PR description summary'
      PROSE = 'visible Intent and Verification prose; a walkthrough omits this and the rule above it'

      attr_reader :notes

      def initialize(options)
        @options = options
        @notes = []
      end

      def sections
        raise Error, 'prompt show opening takes no --head or --base' if @options.key?(:head)

        sections = OpeningPublication.new(root: @options.fetch(:root), ref: @options.fetch(:criteria_ref))
                                     .prompt_sections("<#{OPENING}>", prose: "<#{PROSE}>")
        return unless sections

        instructions, rule, opening, prose_rule, prose = sections
        [instructions, rule, opening.with(source: "placeholder: #{OPENING}"), prose_rule,
         prose.with(source: "placeholder: #{PROSE}")]
      end
    end
  end
end
