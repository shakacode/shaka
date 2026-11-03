# Writing preferences

Tell the agent who will read the PR and what helps them decide:

```text
Write for a product manager. Keep the description short, show the changed
behavior, and put implementation details in the walkthrough.
```

For a preference across tasks, put it in your repository's `AGENTS.md`.
Shaka does not create or edit that file during installation. For a longer style
guide, add a conditional pointer, for example:

```text
When writing product guides, read docs/editorial-style.md.
```

The agent follows those preferences alongside Shaka's writing defaults. Ruby
checks [length limits](settings.md#prose_limits), not whether the prose is useful
or follows your style.
