
Walkthrough input:
  --content-file renders the walkthrough from JSON and posts its inline notes; prefer it.
  --body-file posts Markdown you already rendered, without notes. The ready checkpoint
  recognizes it only when its first line is the writer identity, it has a
  "# Code Walkthrough" heading, and its last line is the commit footer naming --head.
  The command refuses any other body before writing to GitHub. A minimal body:

    🤖 Claude Code · Anthropic · claude-opus-5-5 · medium

    # Code Walkthrough

    [The new check](https://github.com/OWNER/REPO/blob/HEAD_SHA/lib/check.rb#L4) refuses a bad body; validate passed.

    _Walkthrough for commit `HEAD_SHA`. This is a COMMENT, not an approval._

  Both inputs also need a commit-pinned link to a changed file and the names of the
  completed required checks and review jobs, which GitHub reports at publication.
