# Developing Shaka

Shaka's runtime uses Ruby's standard library and the authenticated `gh` CLI.
Development adds Minitest and RuboCop through Bundler. Read the repository's
[AGENTS.md](../../AGENTS.md) before making changes.

## Run the checks

From a checkout:

```bash
.agents/bin/setup
.agents/bin/test test/repository_config_test.rb
.agents/bin/validate
```

`setup` installs the bundle. `test` accepts test-file paths and runs all tests
when none are given. `validate` applies the documentation-only check or runs the
full test and lint suites. Use `bin/validate` to run the full suites explicitly.

Shaka's own `validate` already selects a fast path for documentation-only changes,
and GitHub CI starts on pushes. This repository currently uses the three required
wrappers. Add `validate-local` or `trigger-hosted-ci` when a distinct fast suite or
staged CI workflow needs them; duplicating `validate` would add no capability.

## Executable entry points

| Path | Purpose |
| --- | --- |
| `bin/install` | Link skills into an explicitly supplied directory |
| `skills/shaka/scripts/shaka` | Source installation's CLI entry point |
| `skills/shaka/scripts/cursor-usage-hook` | Save allowlisted Cursor stop-event usage fields |
| `exe/shaka` | Gem executable forwarding to the same CLI |
| `exe/shaka-install` | Gem executable forwarding to the installer |
| `.agents/bin/setup`, `test`, `validate` | This repository's standard agent interface |
| `bin/validate` | Run every Ruby test, then RuboCop |
| `bin/docs-only-change` | Classify a diff for the narrow documentation-only validation path |

The source and gem wrappers expose the same implementation. The CLI dispatches
to modules under `skills/shaka/lib/shaka/`. Run an installed helper's `--help`
for its supported commands and flags.

## Configuration files

| File | Controls |
| --- | --- |
| `.ruby-version` | Development and CI Ruby version |
| `Gemfile`, `Gemfile.lock` | Development dependencies and resolved versions |
| `shaka.gemspec` | Package contents, executables, Ruby requirement, and metadata |
| `.rubocop.yml` | Lint plugins and repository-specific exceptions |
| `.agents/agent-workflow.yml` | Shaka policy for this repository |
| `.agents/trusted-github-actors.yml` | Which public comment authors Shaka may read |
| `skills/shaka/config/workflow.yml` | Packaged delivery procedure |
| `skills/shaka/config/enforcement.yml` | Audit of that procedure's enforcement |
| `.github/workflows/validate.yml` | Required validation on PRs, merge groups, and `main` |
| `.github/workflows/codeql.yml` | Ruby code scanning |
| `.github/workflows/claude-code-review.yml` | Hosted Claude review and execution-status reporting |
| `.github/dependabot.yml` | Weekly GitHub Actions and Bundler updates |
| `.coderabbit.yaml` | CodeRabbit presentation preference |

Live GitHub settings determine required checks and approvals. A workflow filename
or a successful review job alone cannot establish merge readiness.

## Documentation layout

- `README.md` explains the product and its benefits.
- `docs/` contains installation, usage, and configuration guides.
- `docs/reference/` defines settings and defaults for both readers and agents.
- `docs/agents/` supports the installed skills in any repository.
- `docs/contributing/` contains development guidance, dated evidence, and proposals.
- `docs/pilot-plan.md` owns requirements and acceptance.

Keep one maintained source for each detailed rule and link to it. Test code and
failure handling rather than exact wording. For a documentation reorganization,
check navigation and relative links as well as package contents. A fresh-reader
trial is separate evidence from a link check or code review.
