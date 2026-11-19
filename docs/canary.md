# Read a canary run

After a merge to `main`, Shaka opens a pull request in a sandbox repository
and checks the description you would see. A green run opened that pull
request and the automatic checks passed. A red run names the failed check
in the job log and the workflow summary, and links the Shaka commits it
covered.

Open the canary pull request and skim it. The checks catch broken
rendering. They do not decide whether the change was a good idea. The
pull request comment shows the body diff against the previous canary pull
request, plus time and spend. A missing amount stays `UNKNOWN`.

The description check requires the AI spend on the model line and the
current head's intervals in Timings, from
[issue 899](https://github.com/shakacode/shaka/issues/899).

A run with the repository, model key, or token unset posts a notice and
succeeds. Merging this workflow is safe before the setup below.

Manual runs start immediately and test the selected ref; choose `main` to
test merged code. A push waits until about an hour after the
previous agent start, including failed or cancelled attempts. A newer push cancels the run still in progress,
so the run that finishes uses the latest `main`.

## Set it up once

Do this in the GitHub settings. This repository does not create the sandbox,
set secrets, or change organization settings.

1. Create an empty repository. `shakacode/shaka-canary` is a clear name.
   Set the default branch to `main`. Keep other work out of it.
2. Copy [`templates/shaka-canary`](https://github.com/shakacode/shaka/tree/main/templates/shaka-canary)
   to that repository's root, commit, and push to `main`. The
   `.agents/shaka/` files come from `shaka seam init` with review `none`
   and merge `ask`. Validation runs one Ruby file, with no gems.
3. In `shakacode/shaka`, set the Actions variable `SHAKA_CANARY_REPO` to
   `owner/name`.
4. Set the secret `SHAKA_CANARY_MODEL_KEY` to a Cursor API key from the
   Cursor dashboard. Preflight receives `SHAKA_CANARY_MODEL_KEY` to check
   that it is set. The agent step receives it as `CURSOR_API_KEY`.
   The separate Cursor installer step receives neither the model key nor
   the sandbox write token.
5. Set the secret `SHAKA_CANARY_TOKEN` to a user-owned personal access token that can clone the
   sandbox, push branches, and open and close pull requests.
   `gh repo view OWNER/REPO --json viewerPermission` must report `WRITE`
   or `ADMIN`. A blank permission fails `doctor --brief` and the canary
   goes red. GitHub App installation tokens are unsupported here.
   If the token's user identity cannot be read, previous elapsed time stays
   `UNKNOWN`. Reviewer CLIs on the runner are a separate gap,
   [issue 796](https://github.com/shakacode/shaka/issues/796).
6. Optionally set `SHAKA_CANARY_KEEP` to how many open canary pull
   requests to keep. The default is 5. Older open pull requests are closed.
7. Use Actions → Canary → Run workflow to try it. Do not merge the canary
   pull requests. `main` should stay the template so every run repeats the
   same task: add `farewell`, its test, and one docs line. Each Actions
   attempt uses the branch Shaka's claim command names for `run-ID-ATTEMPT`,
   currently `shaka-canary/ad-hoc-run-ID-ATTEMPT`. Checks and
   cleanup ignore fork pull requests and branches outside that pattern.

Review is `none` in the template so the sandbox can finish without
reviewer CLIs. Turn review on after a reviewer key exists if you want the
canary to exercise that part of the workflow.
