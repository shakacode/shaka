# frozen_string_literal: true

require_relative '../configuration'

module Shaka
  # Adds checkpoint.extra_prompt_file to whichever checkpoint prompt applies, after AGENTS.md files.
  module PostImplementationRepositoryRules
    PRECEDENCE = File.expand_path('../../../config/checkpoint-rules-precedence.md', __dir__)
    LABEL = 'checkpoint.extra_prompt_file'

    private

    def repository_rules(marker)
      path, = extra_prompt
      text = repository_rules_text(path)
      return '' unless text

      @rules_source = path
      label = "TRUSTED CHECKPOINT RULES #{marker}"
      "--- BEGIN #{label} FROM #{settings_ref}:#{path} ---\n#{File.read(PRECEDENCE, encoding: 'UTF-8')}\n" \
        "#{text}\n--- END #{label} ---\n\n"
    end

    # Read like a configured prompt: the private tree for individual setup, otherwise the settings commit.
    # A file the settings name must exist; the default file is optional.
    def repository_rules_text(path)
      _, named = extra_prompt
      if individual_prompt?(path)
        return Configuration.private_prompt(root:, path:, label: LABEL) if named

        return Configuration.optional_private_prompt(root:, path:)
      end

      access = { executable: git_executable, capture: method(:capture), resolver: method(:bounded_git) }
      return Configuration.prompt_at_commit(root:, ref: settings_ref, path:, git_access: access) if named

      Configuration.optional_prompt_at_commit(root:, ref: settings_ref, path:, git_access: access)
    end

    def extra_prompt
      @extra_prompt ||= RepositoryConfig::PostImplementationSchema.extra_prompt(
        (effective_review || {}).fetch('post_implementation', {})
      )
    end

    def prompt_source
      [super, @rules_source].compact.join(' + ')
    end
  end
end
