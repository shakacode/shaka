# frozen_string_literal: true

require_relative '../trusted_path_resolver'
require_relative '../defaults'
require_relative 'review_schema'
require_relative 'post_implementation_schema'
require_relative 'project_guidance_schema'

module Shaka
  class RepositoryConfig
    # Every prompt file the settings name, and the warning when the default custom instructions are ignored.
    module PromptFiles
      KEY = ReviewSchema::PROMPT_FILE
      CHECKPOINT = PostImplementationSchema

      module_function

      # The code review's custom instructions path, and whether settings named it; a named file must exist.
      def review_custom_instructions(review)
        key = ReviewSchema::CUSTOM_INSTRUCTIONS
        [review.fetch(key) { Defaults.fetch('review', key) }, review.key?(key)]
      end

      def list(review:, opening:, guidance: {})
        files = review_files(review) + checkpoint_files(review)
        files += [["opening_check.#{KEY}", opening[KEY]]] if opening[KEY]
        files + ProjectGuidanceSchema.prompt_files(guidance)
      end

      def review_files(review)
        agents = Array(review[ReviewSchema::LOCAL_REVIEW_AGENTS]).each_with_index.map do |entry, index|
          ["review.#{ReviewSchema::LOCAL_REVIEW_AGENTS}[#{index}].#{KEY}", entry[KEY]]
        end
        custom = ReviewSchema::CUSTOM_INSTRUCTIONS
        ([["review.#{KEY}", review[KEY]], ["review.#{custom}", review[custom]]] + agents).select { |_, path| path }
      end

      def checkpoint_files(review)
        [KEY, CHECKPOINT::CUSTOM].map { |name| ["checkpoint.#{name}", review.dig(CHECKPOINT::KEY, name)] }
                                 .select { |_, path| path }
      end

      # Each custom instructions setting: its label, the chosen path, whether the settings named it, and its default.
      def custom_instructions(review)
        checkpoint = review.fetch(CHECKPOINT::KEY, {})
        [['review', *review_custom_instructions(review), Defaults.fetch('review', ReviewSchema::CUSTOM_INSTRUCTIONS)],
         ['checkpoint', *CHECKPOINT.custom_instructions(checkpoint), CHECKPOINT::DEFAULTS.fetch(CHECKPOINT::CUSTOM)]]
      end

      # Default files the settings leave unnamed; each counts as read input only where it exists.
      def unnamed_defaults(review) = custom_instructions(review).reject { |_, _, named, _| named }.map(&:last)

      # A file left at a default path is ignored once the settings name another one.
      def warnings(root:, sha:, review:)
        custom_instructions(review).filter_map do |section, path, named, default|
          next unless named && path != default && present?(root, sha, default)

          "#{default} is ignored because #{section}.custom_instructions_file names #{path}. Tell your agent " \
            "which file holds your #{section} instructions, and it will remove the other."
        end
      end

      def present?(root, sha, path)
        sha ? !TrustedPathResolver.new(root:, sha:).resolve(path).last.nil? : File.exist?(File.join(root, path))
      end
    end
  end
end
