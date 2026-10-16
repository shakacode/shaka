# Shaka's own settings

These are the settings Shaka uses when it works on its own code. Copy them as a
starting point for your repository. You rarely need to edit them by hand; ask your
agent instead, for example `$shaka Prefer Claude for code review.` The
[settings reference](https://shaka.shakacode.com/docs/settings) explains every option.

## Where we differ from the defaults

Most changes to Shaka edit the instructions its agents follow. Every extra line of
instructions costs time and money on later tasks, so we ask reviewers to judge
whether new instructions are worth that cost, not only whether they are correct.

- **Code review prompt.** [review-prompt.md](review-prompt.md) replaces Shaka's
  [default review prompt](../../skills/shaka/config/review-prompt.md). It adds that
  cost check, and checks that people can reach any new procedure from the skill.
- **Final check before merge.** [product-checkpoint.md](product-checkpoint.md)
  replaces the [default checkpoint prompt](../../skills/shaka/config/post-implementation-prompt.md)
  and adds the same cost check.
- **Three reviewers.** Claude, Codex, and DeepSeek each review every commit; the
  default is one. A mistake here can weaken the checks Shaka runs on every project.
