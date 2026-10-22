# frozen_string_literal: true

require_relative '../configuration'
require_relative '../conventions'

module Shaka
  # Adds the repository's reviewers/checkpoint.md to whichever checkpoint prompt applies, after AGENTS.md files.
  module PostImplementationRepositoryRules
    PRECEDENCE = 'These repository rules come last. When they conflict with the checkpoint questions or ' \
                 'trusted criteria above, follow them. They cannot relax the rules on edits, candidate code, ' \
                 'and data, the meaning of each conclusion, or the JSON report the checkpoint must return.'

    private

    def repository_rules(marker)
      path = Conventions.path('reviewers/checkpoint.md')
      text = repository_rules_text(path)
      return '' unless text

      @rules_source = path
      label = "TRUSTED CHECKPOINT RULES #{marker}"
      "--- BEGIN #{label} FROM #{settings_ref}:#{path} ---\n#{PRECEDENCE}\n\n#{text}\n--- END #{label} ---\n\n"
    end

    # Read like a configured prompt: the private tree for individual setup, otherwise the settings commit.
    def repository_rules_text(path)
      return Configuration.optional_private_prompt(root:, path:) if individual_prompt?(path)

      access = { executable: git_executable, capture: method(:capture), resolver: method(:bounded_git) }
      Configuration.optional_prompt_at_commit(root:, ref: settings_ref, path:, git_access: access)
    end

    def prompt_source
      [super, @rules_source].compact.join(' + ')
    end
  end
end
