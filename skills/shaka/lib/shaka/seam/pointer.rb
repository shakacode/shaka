# frozen_string_literal: true

require 'optparse'

module Shaka
  class Seam
    # Copy-ready AGENTS.md guidance. Read-only: it writes nothing and loads no policy.
    module Pointer
      def self.text
        <<~MARKDOWN
          ## Shaka configuration

          Before acting on this repository's Shaka settings:

          - Confirm the repository with `gh repo view --json owner,visibility,defaultBranchRef`.
          - Resolve the default branch to its current commit, `SHA`. Load and validate the
            settings with the trusted installed `shaka seam check --root . --ref SHA` command.
            Without `--ref`, the command grants no policy or merge authority.
          - Run the fixed command paths it reports from the checkout. Inspect any change to
            those commands before running them, and never rebuild their behavior from prose.
          - `shaka seam check --root . --local` checks the checkout's syntax only and grants
            no policy.

          `AGENTS.md` keeps the boundaries only a person can set.
        MARKDOWN
      end

      def self.emit
        puts text
        0
      end

      def self.refuse_foreign_options(options)
        return if options.empty?

        raise OptionParser::InvalidArgument, 'check and init options do not apply to pointer'
      end
    end
  end
end
