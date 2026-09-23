# Configuration and command map

Shaka has two kinds of repository input: **policy** loaded from the trusted default branch, and **commands** run from the checkout being changed. This distinction matters when a PR edits its own configuration or scripts.

| File | Who uses it | Purpose |
| --- | --- | --- |
| `AGENTS.md` | Agent | Human-readable repository boundaries that do not fit the typed contract. |
| `.agents/agent-workflow.yml` | `shaka seam check` | Base branch, review policy, merge preference, branch naming, and recovery settings. The trusted default-branch copy grants policy; a candidate copy can only be syntax-checked. |
| `.agents/trusted-github-actors.yml` | `shaka comments` | Repository allowlist for public issue, PR, and review prose. Shaka reads the current default-branch copy, never a PR's proposed copy. |
| `.agents/bin/setup` | Agent | Prepare a checkout. |
| `.agents/bin/test` | Agent | Run focused tests; forward test selections. |
| `.agents/bin/validate` | Agent and CI | Run the full validation gate. |
| `.agents/bin/validate-local` | Agent, if present on the trusted branch | Run a faster pre-review check. |
| `.agents/bin/trigger-hosted-ci` | Agent, if present with `validate-local` | Start hosted CI after repairs. |

The fixed script names are intentional: the agent can call the same operations in every repository without a path-routing table. The scripts themselves are repository-owned, so review changes to a script before executing that checkout's version. [Settings](settings.md) defines every YAML key and script validation rule. [Public comments](public-comments.md) explains the actor allowlist.

Shaka's own package has two different configuration files:

| File | Purpose |
| --- | --- |
| [`skills/shaka/config/workflow.yml`](../../skills/shaka/config/workflow.yml) | The ordered agent procedure rendered by `shaka workflow`. |
| [`skills/shaka/config/enforcement.yml`](../../skills/shaka/config/enforcement.yml) | Classifies what enforces each strong rule in that procedure. `shaka enforcement` prints the classification and fails if a quoted rule disappears or a new strong-rule phrase is unclassified. |

`workflow.yml` tells the agent what to do; `enforcement.yml` records whether a command, GitHub, or only the agent prevents a violation. A passing enforcement check does not prove every sentence is enforceable: a new clause inside an already quoted passage still needs human review.
