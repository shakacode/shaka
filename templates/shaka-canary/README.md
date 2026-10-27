# Shaka canary

Copy this directory to the root of an empty repository and push it to `main`.
Shaka's canary workflow then opens pull requests here. Each run adds a
`farewell` function, a test, and one line in `docs/notes.md`.

Leave `main` on this template. Do not merge the canary pull requests.
The workflow closes older ones.

`.agents/shaka/` comes from `shaka seam init` with review set to `none` and
merge set to `ask`, so the sandbox can open a pull request without reviewer
CLIs. Validation runs `ruby test/greeting_test.rb`.

Setup for the workflow that opens those pull requests is in
[the canary guide](https://github.com/shakacode/shaka/blob/main/docs/canary.md).
