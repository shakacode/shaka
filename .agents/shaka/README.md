# Shaka's own configuration

These files configure Shaka for this repository. They also serve as a working
example: copy a file and change its values. Each value links to its
[settings reference](https://shaka.shakacode.com/docs/settings) entry in the
file's comments. This page explains where this repository departs from Shaka's defaults.
Shaka sends prompt files to reviewers verbatim, so their explanations live here.

| File | What it sets | Docs |
| --- | --- | --- |
| [`config.yml`](config.yml) | Review, merge, branch, WIP, and PR description settings | [Settings reference](https://shaka.shakacode.com/docs/settings) |
| [`review-prompt.md`](review-prompt.md) | What local code reviewers look for | [`review.prompt_file`](https://shaka.shakacode.com/docs/settings#reviewprompt_file) |
| [`product-checkpoint.md`](product-checkpoint.md) | How the checkpoint judges the finished result | [`review.post_implementation`](https://shaka.shakacode.com/docs/settings#reviewpost_implementation) |
| [`trusted-github-actors.yml`](trusted-github-actors.yml) | Whose public comments the agent may read | [Ignored PR comments](https://shaka.shakacode.com/docs/faq#why-did-the-agent-ignore-a-pr-comment) |
| [`bin/`](bin/) | Setup, test, and validation commands | [Standard command scripts](https://shaka.shakacode.com/docs/settings#standard-command-scripts) |

## Where this repository differs from the defaults

Most Shaka changes edit agent instructions, which agents read on every task they
apply to. This repository asks reviewers to weigh that context cost. The criteria are in
[AGENTS.md](../../AGENTS.md#skill-architecture-and-review).

### Review prompt

[`review-prompt.md`](review-prompt.md) replaces Shaka's
[packaged review prompt](../../skills/shaka/config/review-prompt.md). It keeps
the checks for correctness, contract drift, trust boundaries, and regression
coverage, and the Coverage and Findings report format. It adds two checks:

- Instruction changes are judged against the AGENTS.md criteria, using the
  `bin/report-instruction-growth` output and when each file actually loads
  ([#461](https://github.com/shakacode/shaka/pull/461)).
- A new user-invoked procedure must be reachable from its documented entry point.
  A trial that named the procedure file directly once let reviews pass a procedure
  the skill never routed to ([#529](https://github.com/shakacode/shaka/pull/529)).

### Checkpoint prompt

[`product-checkpoint.md`](product-checkpoint.md) replaces Shaka's
[packaged checkpoint prompt](../../skills/shaka/config/post-implementation-prompt.md)
with a shorter version. It applies the same AGENTS.md criteria to instruction
changes ([#461](https://github.com/shakacode/shaka/pull/461)). It also lists earlier
review findings among the unresolved concerns. The task owner turns the result into
a recommendation ([#501](https://github.com/shakacode/shaka/pull/501)).

### Three local reviewers

`local_review_count` is 3; the default is 1. Claude, Codex, and DeepSeek each
review every commit, because a change here can alter the review and merge gates
themselves. DeepSeek runs at low effort; its first trial review cost about one cent
([#506](https://github.com/shakacode/shaka/pull/506)). Grok is listed last as a
fallback when another reviewer cannot run.

### Validation script

[`bin/validate`](bin/validate) skips Ruby tests and RuboCop when a change touches only
`README.md` or `docs/`. It still checks whitespace and docs navigation. Every other
change runs the repository's full [`bin/validate`](../../bin/validate).

### Repository choices without a default

`review.required`, `review.ci_review_jobs`, `review.local_review_agents`, and the
trusted actors have no default. This repository sets `required: meaningful_changes`
and waits for its hosted `claude-review` job from
[Claude Code Review](../../.github/workflows/claude-code-review.yml).

Every other value in `config.yml` restates Shaka's default so readers can see it.
[A test](../../test/repository_configuration_example_test.rb) fails when a default
changes and `config.yml` does not.
