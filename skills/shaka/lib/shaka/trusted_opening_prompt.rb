# frozen_string_literal: true

module Shaka
  # Resolves the optional opening prompt from the immutable seam commit.
  module TrustedOpeningPrompt
    def opening_prompt(config)
      path = config.opening_check['prompt_file']
      return unless path

      resolved, = TrustedPathResolver.new(root: @root, sha: config.sha).resolve(path)
      git_output(config.sha, resolved, '-p')
    end

    private

    def validate_opening_prompt(opening, sha)
      path = opening['prompt_file']
      return unless path

      resolver = TrustedPathResolver.new(root: @root, sha:)
      resolved, entry = resolver.resolve(path)
      is_blob = entry && entry.last == 'blob' && entry.first != TrustedPathResolver::SYMLINK.first
      raise Error, "opening_check.prompt_file does not name a file at #{sha}: #{path}" unless is_blob

      error = ReviewPrompt.file_error(git_output(sha, resolved, '-s').to_i) { git_output(sha, resolved, '-p') }
      raise Error, "opening_check.prompt_file #{path} at #{sha} #{error}" if error
    end
  end
end
