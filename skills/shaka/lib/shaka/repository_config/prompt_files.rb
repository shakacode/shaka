# frozen_string_literal: true

require_relative '../trusted_path_resolver'
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

      def list(review:, opening:, guidance: {})
        files = review_files(review) + checkpoint_files(review)
        files += [["opening_check.#{KEY}", opening[KEY]]] if opening[KEY]
        files + ProjectGuidanceSchema.prompt_files(guidance)
      end

      def review_files(review)
        agents = Array(review[ReviewSchema::LOCAL_REVIEW_AGENTS]).each_with_index.map do |entry, index|
          ["review.#{ReviewSchema::LOCAL_REVIEW_AGENTS}[#{index}].#{KEY}", entry[KEY]]
        end
        ([["review.#{KEY}", review[KEY]]] + agents).select { |_, path| path }
      end

      def checkpoint_files(review)
        [KEY, CHECKPOINT::CUSTOM].map { |name| ["checkpoint.#{name}", review.dig(CHECKPOINT::KEY, name)] }
                                 .select { |_, path| path }
      end

      # A file left at the default path is ignored once the settings name another one.
      def warnings(root:, sha:, review:)
        path, named = CHECKPOINT.custom_instructions(review.fetch(CHECKPOINT::KEY, {}))
        default = CHECKPOINT::DEFAULTS.fetch(CHECKPOINT::CUSTOM)
        return [] unless named && path != default && present?(root, sha, default)

        ["#{default} is ignored because checkpoint.#{CHECKPOINT::CUSTOM} names #{path}. Tell your agent which " \
         'file holds your checkpoint instructions, and it will remove the other.']
      end

      def present?(root, sha, path)
        sha ? !TrustedPathResolver.new(root:, sha:).resolve(path).last.nil? : File.exist?(File.join(root, path))
      end
    end
  end
end
