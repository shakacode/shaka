# Developing Shaka

Read [AGENTS.md](https://github.com/shakacode/shaka/blob/main/AGENTS.md) before changing the project. Runtime code uses Ruby's
standard library and `gh`; development adds Minitest and RuboCop through Bundler.
Install Node.js 22.19 or newer for the Pi extension tests. No npm installation is needed.

```bash
.agents/shaka/bin/setup
.agents/shaka/bin/test test/repository_config_test.rb
.agents/shaka/bin/validate
```

`setup` installs dependencies for working on Shaka. `bin/install` instead links
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

## Set up the canary


Do this in the GitHub settings. This repository does not create the sandbox,
set secrets, or change organization settings.

1. Create an empty repository. `shakacode/shaka-canary` is a clear name.
   Set the default branch to `main`. Keep other work out of it.
2. Copy [`templates/shaka-canary`](https://github.com/shakacode/shaka/tree/main/templates/shaka-canary)
   to that repository's root, commit, and push to `main`. The
   `.agents/shaka/` files come from `shaka seam init` with review `none`
   and merge `ask`. Validation runs one Ruby file, with no gems.
3. In `shakacode/shaka`, set the Actions variable `SHAKA_CANARY_REPO` to
   `owner/name`.
4. Set the secret `SHAKA_CANARY_MODEL_KEY` to a Cursor API key from the
   Cursor dashboard. Preflight receives `SHAKA_CANARY_MODEL_KEY` to check
   that it is set. The agent step receives it as `CURSOR_API_KEY`.
   The separate Cursor installer step receives neither the model key nor
   the sandbox write token.
5. Set the secret `SHAKA_CANARY_TOKEN` to a user-owned personal access token that can clone the
   sandbox, push branches, and open and close pull requests.
   `gh repo view OWNER/REPO --json viewerPermission` must report `WRITE`
   or `ADMIN`. A blank permission fails `doctor --brief` and the canary
   goes red. GitHub App installation tokens are unsupported here.
   If the token's user identity cannot be read, previous elapsed time stays
   `UNKNOWN`. Reviewer CLIs on the runner are a separate gap,
   [issue 796](https://github.com/shakacode/shaka/issues/796).
6. Optionally set `SHAKA_CANARY_KEEP` to how many open canary pull
   requests to keep. The default is 5. Older open pull requests are closed.
7. Use Actions → Canary → Run workflow to try it. Do not merge the canary
   pull requests. `main` should stay the template so every run repeats the
   same task: add `farewell`, its test, and one docs line. Each Actions
   attempt uses the branch Shaka's claim command names for `run-ID-ATTEMPT`,
   currently `shaka-canary/ad-hoc-run-ID-ATTEMPT`. Checks and
   cleanup ignore fork pull requests and branches outside that pattern.

Review is `none` in the template so the sandbox can finish without
reviewer CLIs. Turn review on after a reviewer key exists if you want the
canary to exercise that part of the workflow.
