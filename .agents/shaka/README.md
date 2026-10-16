# Shaka's own configuration

A working example of Shaka's settings. You need not edit these files: ask the skill,
such as `$shaka Prefer Claude for code review.` See the
[settings reference](https://shaka.shakacode.com/docs/settings).

## Where this repository differs from the defaults

Most Shaka changes edit agent instructions, so reviewers here also judge their cost
against the [AGENTS.md criteria](../../AGENTS.md#skill-architecture-and-review).

- [`review-prompt.md`](review-prompt.md) replaces the
  [default review prompt](../../skills/shaka/config/review-prompt.md) to add those
  criteria and a check that new procedures are reachable from the skill.
- [`product-checkpoint.md`](product-checkpoint.md) replaces the
  [default checkpoint prompt](../../skills/shaka/config/post-implementation-prompt.md)
  to add the same criteria.
- `local_review_count: 3` (default 1) has Claude, Codex, and DeepSeek review each commit,
  because changes here can alter Shaka's own review and merge gates.
