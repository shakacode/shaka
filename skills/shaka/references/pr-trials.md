# Prepare and report a PR trial

Use this procedure for an explicit request to try an unmerged **Shaka tool PR** on
a separate project task. Distinguish the candidate tool URL from the issue or PR
being fixed. Ordinary `$shaka PR_URL` requests still mean work on that PR.

## Prepare with the normal helper

Before beginning the project task, use the saved trusted helper:

```bash
shaka trial prepare https://github.com/shakacode/shaka/pull/359 \
  --root /path/to/project --task 'Fix the search bug.' > /outside/project/trial.json
```

Use the absolute saved helper in place of `shaka`. `--directory DIR` selects trial
storage; the default is `~/.local/share/shaka/pr-trials`. Storage and temporary
source checkouts belong outside the target checkout. Normal skill links are not
switched. The command verifies an open PR in `shakacode/shaka`, fetches its head,
and uses the bootstrap's existing installer to copy it, without running the
candidate installer or helper. A moving head fails preparation; retry to select
the new revision. This first version prepares a prompt; it does not launch a host.

Inspect the returned `candidate_head`, `skill`, `helper`, `report_helper`, and
`startup_prompt`. Give the user the startup prompt for a fresh chat. Stop the
preparation there; do not switch the running task's helper. In the fresh chat,
resolve the explicitly selected skill outside the project, read its workflow,
and retain its absolute helper for that task. Selecting experimental agent
instructions and code is opt-in, not a security review of the candidate.

The target's trusted default-branch seam and human instructions still govern its
settings and merge authority. Explain compatibility problems through the normal
setup or migration procedure instead of silently using candidate configuration.
Record the selected candidate URL and exact commit in the result PR alongside
workflow provenance. One task tests one candidate; prepare again for another head.

## Publish authorized feedback

The candidate may predate these commands. Keep `report_helper` from the bootstrap
JSON and use that absolute helper for reporting after the task. Read its packaged
copy of this reference, not a checkout-provided replacement. Obtain the user's
authorization to publish feedback; a preparation request alone does not authorize
a public comment. Review every field and link for private content.

Write report JSON outside project checkouts:

```json
{
  "id": "search-fix-1",
  "candidate_head": "FULL_40_CHARACTER_SHA_FROM_PREPARATION",
  "result_url": "https://github.com/OWNER/REPO/pull/NUMBER",
  "verdict": "revise",
  "summary": "The checkpoint helped me choose the fix. I had to correct its timing."
}
```

Then run the retained bootstrap helper:

```bash
shaka trial report https://github.com/shakacode/shaka/pull/359 \
  --content-file /outside/project/report.json
```

`id` is a public name of 1–48 letters, digits, or hyphens, starting with a letter or
digit. Verdicts are `keep`, `revise`, or `drop`. Use a nonempty public-safe summary.
The helper verifies that a public result PR records the exact Shaka commit URL
in its body. It checks repository visibility before publishing GitHub links,
adds `eval-required` to an open candidate, and publishes a tester-attributed comment.
It does not independently prove which instructions an agent followed.

For private results, omit `result_url` and set `"private_result": true`. Keep
private links and context in the private result PR; publish only an authorized
public-safe summary. GitHub link checks cannot classify confidential prose or
links to other services. A failed check publishes no feedback comment.

Reuse the same id and revision to update a report. A new id or revision retains a
separate report, so repeated trials can show different outcomes. There is no
results database, automatic vote tally, adoption, or merge decision. Return to
normal Shaka by starting a new chat with the usual installed skill.
