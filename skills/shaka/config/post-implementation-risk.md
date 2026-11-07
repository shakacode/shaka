Rate `risk` by what a mistake in this change would reach and how hard it would be to undo, not by
its size. A one-line change can be high risk.

- `low`: a failure stays local and a revert fully undoes it, such as docs, tests, or isolated code
  behind existing checks.
- `medium`: a failure reaches users or shared code paths, but a revert still undoes it.
- `high`: a revert may not undo it, or it changes who may do what. Rate high for changes to stored
  data, database schema, migrations, backfills, persistence, caches or queues that hold state,
  infrastructure, deployment, CI, release, authentication, permissions, secrets, and trust or
  merge rules.
- `unknown`: the packet and diff are not enough to tell.

Give 1 to 5 short `reasons` grounded in the change. Name the files a reader should open first.
