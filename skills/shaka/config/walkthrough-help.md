
Walkthrough input:
  --content-file renders the walkthrough from JSON and posts its inline notes; prefer it.
  Save this minimal JSON object as walkthrough.json and pass --content-file walkthrough.json:

```json
{
  "identity": {},
  "summary": "The check refuses invalid input."
}
```

  Supply identity: {} for portable input. The summary must be nonempty Markdown text
  (not a body field).
  Identity fields agent, provider, model, and effort are single-line strings; missing or
  empty fields render UNKNOWN. Native attribution sets agent and supplies observed model
  and effort. Codex also supplies observed provider; Claude keeps provider as supplied.
  The command supplies head from --head; a head field in the JSON does not override it.
  Optional structures:
  - sections: array of objects with heading (nonempty single-line string) and body
    (nonempty Markdown string). Decisions to make and Decisions for the maintainer
    are reserved headings (case-insensitive, ignoring surrounding whitespace).
  - table: object with columns (nonempty array of nonempty single-line strings) and
    rows (nonempty array of arrays with one cell per column). Each cell must yield
    nonempty single-line text.
  - details: array of objects with summary (nonempty single-line string) and body
    (nonempty Markdown string).
  Omit optional structures or use empty sections/details arrays. In prose, use real
  line breaks rather than literal backslash escape sequences. For code_links and notes,
  run shaka workflow and read the Explain phase's field descriptions.

  This example is valid renderer input, not sufficient publication evidence. Before
  publishing, replace its summary with an account of the change and the evidence below.

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
