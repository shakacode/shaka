# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tempfile'
require_relative '../repository_config'
require_relative '../trusted_config_source'
require_relative '../trusted_path_resolver'

module Shaka
  # Reads the repository's review instructions from the same trusted commit as its criteria.
  module LocalReviewPromptFile
    private

    def review_instructions
      script = File.expand_path('../../../scripts/shaka', __dir__)
      with_prompt_arguments do |arguments|
        capture(RbConfig.ruby, script, 'review-prompt', '--head', head,
                '--base', @options[:base], '--reviewer', reviewer, '--effort', effort, *arguments)
      end
    end

    # Yields the `review-prompt` arguments that select the instructions for this reviewer.
    def with_prompt_arguments
      text = trusted_prompt_text
      return yield([]) unless text

      Tempfile.create(['shaka-review-instructions-', '.md']) do |file|
        file.write(text)
        file.close
        yield ['--prompt-file', file.path]
      end
    end

    def trusted_prompt_text
      ref = @options[:criteria_ref]
      return unless ref && trusted_seam?(ref)

      path = configured_prompt_path(TrustedConfigSource.load(root:, ref:, candidate_commands: false).review)
      path && read_trusted_prompt(ref, path)
    end

    # A repository without a seam at that commit keeps the default instructions.
    def trusted_seam?(ref)
      _, _, status = Open3.capture3(git_executable, '-C', root, 'cat-file', '-e', "#{ref}:#{RepositoryConfig::PATH}")
      status.success?
    end

    # A reviewer's own file wins over the repository-wide one.
    def configured_prompt_path(review)
      agents = review.fetch(RepositoryConfig::ReviewSchema::LOCAL_REVIEW_AGENTS, [])
      agent = agents.find { |entry| entry.values_at(*ReviewerSelection::IDENTITY).join('/').downcase == reviewer }
      prompt_file = RepositoryConfig::ReviewSchema::PROMPT_FILE
      agent&.fetch(prompt_file, nil) || review[prompt_file]
    end

    def read_trusted_prompt(ref, path)
      resolved, entry = TrustedPathResolver.new(root:, sha: ref).resolve(path)
      raise Shaka::Error, "Review prompt file #{path} is not a file at #{ref}" unless prompt_blob?(entry)

      capture(git_executable, '-C', root, 'show', "#{ref}:#{resolved}")
    end

    def prompt_blob?(entry) = entry && entry.last == 'blob' && entry.first != TrustedPathResolver::SYMLINK.first
  end
end
