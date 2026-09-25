# frozen_string_literal: true

require 'rbconfig'
require 'tempfile'
require 'yaml'
require_relative '../repository_config'
require_relative '../review_prompt'
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

      path = configured_prompt_path(trusted_review_settings(ref))
      path && read_trusted_prompt(ref, path)
    end

    # Reads only the review section, so the rest of the seam need not be valid for a review to run;
    # `shaka seam check` validates the whole contract.
    def trusted_review_settings(ref)
      source = capture(git_executable, '-C', root, 'show', "#{ref}:#{RepositoryConfig::PATH}")
      data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      review = data.is_a?(Hash) ? data['review'] : nil
      review.is_a?(Hash) ? review : {}
    rescue Psych::Exception => e
      raise Shaka::Error, "Invalid #{RepositoryConfig::PATH} at #{ref}: #{e.message}"
    end

    # A repository without a seam at that commit keeps the default instructions.
    def trusted_seam?(ref)
      timeout = @options.fetch(:timeout_seconds)
      _, _, status = LocalReviewProcess.capture([git_executable, '-C', root, 'cat-file', '-e',
                                                 "#{ref}:#{RepositoryConfig::PATH}"],
                                                stdin_data: nil, chdir: root, timeout:)
      raise Shaka::Error, "git timed out after #{timeout}s" unless status

      status.success?
    end

    # A reviewer's own file wins over the repository-wide one.
    def configured_prompt_path(review)
      agents = Array(review[RepositoryConfig::ReviewSchema::LOCAL_REVIEW_AGENTS]).grep(Hash)
      agent = agents.find { |entry| entry.values_at(*ReviewerSelection::IDENTITY).join('/').downcase == reviewer }
      prompt_file = RepositoryConfig::ReviewSchema::PROMPT_FILE
      path = agent&.key?(prompt_file) ? agent[prompt_file] : review[prompt_file]
      return if path.nil?
      raise Shaka::Error, "review #{prompt_file} must be a repository path" unless path.is_a?(String)

      path
    end

    def read_trusted_prompt(ref, path)
      resolved, entry = TrustedPathResolver.new(root:, sha: ref).resolve(path)
      raise Shaka::Error, "Review prompt file #{path} is not a file at #{ref}" unless prompt_blob?(entry)

      text = capture(git_executable, '-C', root, 'show', "#{ref}:#{resolved}")
      error = ReviewPrompt.instructions_error(text)
      raise Shaka::Error, "Review prompt file #{path} at #{ref} #{error}" if error

      text
    end

    def prompt_blob?(entry) = entry && entry.last == 'blob' && entry.first != TrustedPathResolver::SYMLINK.first
  end
end
