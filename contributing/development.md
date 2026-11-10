# Developing Shaka

Read [AGENTS.md](https://github.com/shakacode/shaka/blob/main/AGENTS.md) before changing the project. Runtime code uses Ruby's
standard library and `gh`; development adds Minitest and RuboCop through Bundler.
Install Node.js 22.19 or newer for the Pi extension tests. No npm installation is needed.

```bash
.agents/shaka/bin/setup
bundle exec lefthook install
.agents/shaka/bin/test test/repository_config_test.rb
.agents/shaka/bin/validate
```

`setup` installs dependencies for working on Shaka. `lefthook install` adds Git
hooks, once per clone, that check only the files you change: a commit with a
Ruby syntax error or a RuboCop offence RuboCop cannot fix is rejected in
seconds, and a push lints every Ruby file the branch changed. The commit hook
also fixes what RuboCop can, adds missing final newlines, and runs the docs link
check when Markdown changes. `validate` warns while the hooks are missing.
`git commit --no-verify` skips them once. `bin/install` instead links
Shaka skills into a coding agent's skills directory. `test` accepts test paths;
`validate` chooses appropriate checks. `bin/validate` runs all tests and lint.

## Where changes belong

| Location | Purpose |
| --- | --- |
| `docs/` | Product guides and settings |
| `skills/shaka/config/workflow.yml` | Ordered agent instructions |
| `skills/shaka/config/enforcement.yml` | Which rules code or the agent enforces |
| `skills/shaka/references/` | Procedures loaded by skills when needed |
| `skills/shaka/lib/shaka/` | Ruby implementation |
| `contributing/` | Development, packaging, and release guidance |
| `internal/` | Public plans, trials, and temporary migration records |

Run `shaka workflow` and `shaka enforcement` after changing the workflow. Check
relative links and packaged references when moving documentation. A passing
link check does not establish usability; use a representative reader task for
a substantial rewrite. See [configuration internals](configuration-internals.md)
for parser and policy boundaries.
