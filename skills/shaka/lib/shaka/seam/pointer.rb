# frozen_string_literal: true

module Shaka
  class Seam
    # Copy-ready AGENTS.md guidance. Read-only: it writes nothing and loads no policy.
    module Pointer
      def self.text
        <<~MARKDOWN
          ## Agent Workflow Configuration

          Verify this repository with `gh repo view OWNER/REPO --json owner,visibility,defaultBranchRef`.
          Resolve the trusted default branch to an immutable commit. Load and validate
          `.agents/agent-workflow.yml` with the trusted installed `shaka seam check --root ROOT --ref REF`
          command. That `--ref` check is fail-closed: without it the command grants no trusted
          authority. Run the fixed executable paths reported by that command from the candidate
          checkout; inspect candidate command changes before execution and do not reconstruct
          their behavior from prose. `shaka seam check --root .` without `--ref` only validates
          current-checkout syntax. `AGENTS.md` retains human-only boundaries.
        MARKDOWN
      end
    end
  end
end
