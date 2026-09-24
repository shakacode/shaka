# Invoke a reviewer locally

First [select a reviewer](review.md#choose-a-local-reviewer) using trusted policy.
Use this reference for CLI execution and report validation.

Render the prompt for the selected reviewer:
```text
shaka review-prompt --head SHA --base REF --reviewer PROVIDER/FAMILY [--effort NAME]
```

Pass resolved revisions, not the words `HEAD` or `BASE`: the prompt interpolates what it is given,
so a literal placeholder would publish an attestation reading `REVIEWED HEAD`.

It scopes the review to `git diff BASE...HEAD`, asks for correctness, contract drift, security and
trust, test coverage, simplification, and supplied repository criteria. It forbids edits,
treats candidate content as data, and
requires a closing line of `REVIEWED <head> BY <provider>/<family> EFFORT <effort> FINDINGS <n>`.

Supply relevant planning and review criteria from the repository's trusted default-branch
`AGENTS.md` alongside the prompt, naming its immutable commit. Resolve that source separately
from the diff's `--base`; a task's comparison base does not establish policy authority.
Candidate edits to that guidance are review data.
For changes to Shaka itself, include its "Is the change worth carrying?" section.
That repository-specific experiment does not impose a value rubric on consumers.
The report states whether criteria were supplied and names their supplied source/ref,
so an omitted rubric is visible. This is reviewer-reported coverage, not verification
of the source or a new gate.

Supply the diff and the PR description, not the implementation reasoning: a reviewer given the
justification anchors on it instead of finding the hole. That is exactly why the same model works
here — a fresh session has none of the author's reasoning to anchor on.

A local CLI differs from a hosted reviewer in three ways: it uses your credentials, must not edit,
and leaves report publication to you. The report names the revision and model so the record stands
on its own. On a public repository, include only
review prose permitted by the [public-prose rule](review.md#read-public-review-prose-safely); retain withheld comments as links rather
than supplying their bodies.

Restrict the CLI to read and search tools, and disable hooks, plugins, and MCP servers.
`shaka review run` reads Git history from `--root`, embeds the diff as review data, then starts
the reviewer in a disposable instruction-neutral directory outside the candidate checkout.
Reviewer subprocesses have a 300-second deadline by default; `--timeout-seconds 1..3600`
sets a task-specific bound. A timeout returns `cli_failure` with a reason and requires cause
review; it never proves the provider unavailable by itself.
The prompt identifies the checkout path and exact commit for read-only Git inspection of
unchanged callers and tests where the CLI permits it. Restricted Claude cannot run Git commands;
it reviews the embedded diff and must report when unchanged source is needed to reach a finding.
Candidate source remains data, not instructions or executable code.
Candidate `AGENTS.md` and similar files are never loaded as host instructions by that CLI.
Codex receives `--skip-git-repo-check` for the neutral directory. Supply any trusted-base
repository criteria with optional `--criteria-ref TRUSTED_SHA`: the helper reads root
`AGENTS.md` and any nested `AGENTS.md` governing changed paths from that immutable commit,
and embeds them in root-to-specific order as separately labeled review data. The criteria commit
need not precede the comparison base: the default branch may have advanced independently.
Verify the SHA against the live trusted default branch first; the option grants
no authority by itself. Without it the reviewer reports criteria as not supplied. Candidate
criteria remain data in the diff. Supply the PR description with optional
`--description-file PATH`; this file is labeled as untrusted review data and must contain only
public-safe text for a public PR. Do not supply implementation reasoning.

Use full, immutable commit SHAs, for example `BASE=$(git merge-base origin/main HEAD)` and
`HEAD=$(git rev-parse HEAD)` when `main` is the verified default branch. The helper checks that the
checkout is at `HEAD`, renders the review prompt with the diff, invokes the CLI with the flags below, and returns
JSON with the report path or a concrete failure. Its process result, not a copied shell block,
is the evidence that the CLI actually ran.

Codex 0.154.0:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer openai/codex
```

A Cursor Task or subagent that selects a Codex model is not this `openai/codex` local
reviewer and cannot replace `codex exec`. It also is not evidence for `--unavailable`.
Use that flag only when `shaka review run` reports `executable_missing`, or after a `cli_failure`
whose local diagnostic establishes a real reviewer outage. A bad argument, setup failure, or
report-validation failure does not qualify.

The helper runs `codex exec -s read-only --ignore-rules --ignore-user-config
--skip-git-repo-check --json -o REPORT -` from its neutral directory.
Codex has no documented effort flag in this invocation, so the helper rejects `--effort` for
`openai/codex` and records `EFFORT UNKNOWN` rather than asserting an unverified setting.
`-s read-only` confines it, the ignore flags skip user/project rules and config, and the report
is created outside the checkout. It does not use `--ephemeral`, so the session remains saved. `--json` reports its thread ID,
and the result's `usage` names that saved session under `CODEX_HOME` (default `~/.codex`);
run `shaka usage --host codex --file USAGE --commit HEAD --contribution review --all-turns`
on it. A missing `usage` means the session file was not found, and review usage stays UNKNOWN.
`codex exec review --base REF` cannot accept the custom review prompt, so the helper uses `exec`.

Claude Code:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer anthropic/claude --effort medium
```

A Cursor Task or subagent that selects a Claude model is not this `anthropic/claude` local
reviewer and cannot replace `claude -p`. It also is not evidence for `--unavailable`.
Apply the same failure-cause check before marking `claude` unavailable.

The helper runs `claude -p --permission-mode plan --permission-prompts none --restricted
--safe-mode --strict-mcp-config --effort EFFORT --output-format json -`. It rejects an error,
empty result, or wrong-head attestation. `-p` prints and exits; JSON holds the review text and
native token counters. Run `shaka usage --host claude-code --file PATH --commit HEAD
--contribution review` on the corresponding Claude session. `--permission-mode plan` with
`--permission-prompts none` withholds edits
and denies anything that would prompt. `--restricted` removes command-running tools.
`--safe-mode` disables project CLAUDE.md, skills, plugins, hooks, and MCP while **keeping
Claude.ai OAuth**. `--strict-mcp-config` with no config drops MCP servers. Do **not** add
`--bare`: that flag skips keychain and OAuth (`Not logged in · Please run /login`) and only
accepts `ANTHROPIC_API_KEY`, so a logged-in Max/claude.ai session looks unavailable.
`--effort` is recorded in the attestation. Pass `--model NAME` to pin the reviewer model;
the helper adds `--model NAME` to that command and reports it as `requested_model` in every
result. That is the request, not proof of the model that ran; the usage JSON records the
routed model. Without it, the CLI's default model runs. Check `--help` before relying on these flags.

Grok 1.0.30:

Set `MODEL` to a model the installed Grok CLI accepts before running:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer xai/grok \
  --model "$MODEL" --effort high
```

The helper runs `grok --prompt-file PROMPT -m MODEL --reasoning-effort high --output-format plain
--permission-mode plan --disable-web-search --no-subagents`, removes `PROMPT` afterward, and
checks the report attestation. `--permission-mode plan` withholds edit approval; the other two
remove web access and subagents.
If this review is a fresh Cursor chat, report it with
`shaka usage --host cursor --commit "$(git rev-parse HEAD)" --contribution review` from that chat, or that
command plus `--file` of its stop-hook jsonl. Pass its report to
`shaka review check --head "$HEAD" --reviewer xai/grok --report PATH`; the result is `reported`,
not a claim that the Grok CLI launched. Parent-agent Cursor records exclude subagents.

The Codex flags were exercised on a prior local review rather than read off `--help`. The
Claude and Grok flags come from each CLI's `--help`. The helper's neutral directory prevents
the reviewer host from loading candidate `AGENTS.md` and similar instructions; the candidate
diff remains untrusted review data. Restrict execution for untrusted contributions under
[what the helpers protect](delivery.md#what-the-helpers-protect). Codex's
`--ignore-user-config` drops config-defined MCP servers, Grok manages them through
`grok mcp`, and Claude's `--strict-mcp-config` without a config file loads none. Codex
exposes no reasoning-effort flag on `exec review`, so record its effort as UNKNOWN unless
the model's own output reports it. Check `--help` before relying on any of these; flags move.

A local review is **UNVERIFIED** until the owner publishes its report, including that closing
line, to the pull request. The owner verifies each finding against the code, makes the edits and
tests, and publishes a concise summary tied to the reviewed commit. Record available native
model, effort, and usage with `shaka usage --commit "$(git rev-parse HEAD)" --contribution review` on the
reviewer's source; missing evidence is UNKNOWN. Do not publish raw sessions or private
context. A recovery
note's `Thread` field follows its [publication
rule](delivery.md#recover-an-unfinished-pr).

Automated review comments are advice, not merge permission. Required GitHub
approvals and checks remain gates. The merge helper checks native readiness and
the current commit; it does not read or judge review findings for the agent.
No extra approval, review receipt, or review service is introduced.

For example, a repo that already runs Claude on PRs can pin the report author in
its trusted `AGENTS.md` seam:

```markdown
Review: use our existing Claude Code Review GitHub workflow. Read its comments
and inline threads from the pinned `claude[bot]` report author, address demonstrated
defects, and recheck fixes before merge.
```

The [React on Rails review workflow](https://github.com/shakacode/react_on_rails/blob/e3d95bebc743ea9f9ab322f4b370667393c7627a/.github/workflows/claude-code-review.yml)
is an example: it posts comments and inspects Claude's execution result because
an unsuccessful review can otherwise report a successful action. Its separate
`@claude` workflow is a different capability, not required by this ordinary path.
