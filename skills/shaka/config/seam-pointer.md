## Shaka configuration

Before acting on this repository's Shaka settings:

- Confirm the repository with `gh repo view --json owner,visibility,defaultBranchRef`.
- Resolve the default branch to its current commit, `SHA`. Load and validate the
  settings with the trusted installed `shaka seam check --root . --ref SHA` command.
  Without `--ref`, the command grants no policy or merge authority.
- Run the fixed command paths it reports from the candidate checkout. Inspect any
  candidate change to those commands before running them, and never rebuild their
  behavior from prose.
- `shaka seam check --root . --local` checks the checkout's syntax only and grants
  no policy.

`AGENTS.md` keeps the boundaries only a person can set.
