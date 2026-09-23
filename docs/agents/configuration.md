# Configuration implementation map

For settings and examples, read [Configuration](../configuration.md). This map
shows where Shaka reads and enforces them.

| Input | Consumer | Authority |
| --- | --- | --- |
| `.agents/agent-workflow.yml` | `shaka seam check --ref SHA` | Policy from the resolved default-branch commit |
| `.agents/bin/*` | Agent and CI | Optional capability from the trusted commit; executable code from the candidate checkout |
| `.agents/trusted-github-actors.yml` | `shaka comments` | Current default-branch allowlist, combined with the machine allowlist |
| `AGENTS.md` | Agent | Trusted repository instructions; candidate edits are review data |

Inspect candidate script changes before execution. `--local` checks the candidate
contract and grants no authority.

## Packaged workflow

| File | Command | Purpose |
| --- | --- | --- |
| [`workflow.yml`](../../skills/shaka/config/workflow.yml) | `shaka workflow` | Validate and render the ordered agent procedure |
| [`enforcement.yml`](../../skills/shaka/config/enforcement.yml) | `shaka enforcement` | Report which rules are enforced by code, GitHub, or the agent |

The enforcement loader checks that quoted rules still exist and that strong-rule
phrases are classified. It cannot detect a new clause inside an already quoted
passage or judge whether a classification is true. Review those changes manually.

## Ruby implementation

Paths below are relative to `skills/shaka/lib/shaka/`.

| Concern | Source |
| --- | --- |
| YAML loading and effective defaults | `repository_config.rb` |
| Root keys and values | `repository_config/schema.rb` |
| Fixed scripts and optional dependencies | `repository_config/command_paths.rb`, `command_schema.rb` |
| Trusted refs and symlink authorization | `trusted_config_source.rb` |
| Review settings and selection | `repository_config/review_schema.rb`, `reviewer_selection.rb` |
| Branch template | `repository_config/branch_schema.rb` |
| Recovery publication setting | `repository_config/recovery_schema.rb` |
| Duplicate keys and document count | `repository_config/duplicate_keys.rb` |
| Initial configuration | `seam/initializer.rb` |
| Migration classification | `seam/field_classifier.rb` |

See [development](../project/development.md) for the repository's other config
files, executable entry points, and checks.
