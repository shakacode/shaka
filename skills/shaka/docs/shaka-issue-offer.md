# Shaka issue-offer procedure

Follow this procedure when the Shaka workflow's **Always** guidance says to offer an issue for a
verified product gap. Only the root task owner runs it; workers report possible gaps to that owner.
Respect a user request to skip offers for the current task. Keep the current task moving while the
user considers the offer.

## Offer before searching

Draft a concise title and body from public sources. Verify the gap in current public Shaka materials
and cite that source in the draft; cite public sources for other factual claims. Exclude details
learned only from the active task or a private repository, as well as private repository names,
branches, file paths, and links. Choose two to four distinctive plain terms from the public draft;
do not use quotes or GitHub search qualifiers. If no safe query can be formed, explain why; do not
search or file, and continue the active task. Show the exact title, body, source links, and query.
Ask whether the user authorizes that search; tell them you will ask again before filing. Continue
the active task while waiting. Do not search if the user declines or has not accepted. If the
accepted text or query changes, show the full revision and ask again.

## Verify the target and search

After acceptance, verify the target is the fixed public Shaka repository,
`shakacode/shaka`. Run `gh repo view shakacode/shaka --json id,nameWithOwner,visibility` and
require live values to match node ID `R_kgDOUZzTGw`, canonical name `shakacode/shaka`, and public
visibility `PUBLIC`. Stop and report any command failure or mismatch before searching.
If the live identity no longer matches because Shaka has legitimately moved or been recreated,
stop and report it. A maintainer must verify and update the pinned identity through the normal
Shaka review process before another search or filing attempt. GitHub CLI calls resolve this
repository by its name, not node ID; a move after either identity check remains a narrow race the
procedure cannot eliminate.

Search every issue and pull-request state; omit `--state`. Ask GitHub to match titles and bodies,
but return only numeric and state metadata:

```sh
gh search issues --repo shakacode/shaka --include-prs --match title,body --limit 1000 \
  --json number,url,isPullRequest,state -- "$QUERY"
```

Pass `QUERY` after `--` as one safely quoted argument. This best-effort search can miss duplicates
when GitHub has no matching indexed text; no results is not proof no issue exists. A result is a
possible duplicate, not a confirmed match: share its returned URL, number, `isPullRequest`, and
state, and wait for the user to inspect it. Do not request or fetch
titles, issue or pull-request descriptions, or comments. If search fails or returns 1,000 results,
report that and do not file an issue. If a search returns no candidates, share its query and
zero-result outcome, then ask whether the user authorizes creating the exact issue.

## File accepted text

If there were no candidates, file only after the user accepts the zero-result caveat and explicitly
authorizes creation. If there were candidates, file only after the user confirms none covers the gap
and explicitly authorizes creation. Reverify the repository identity. Populate `ISSUE_TITLE` and
`ISSUE_BODY_FILE` from the accepted text without changing either value or evaluating the text as
shell syntax. Read the single-line title with `IFS= read -r` from a quoted here-document, choosing
a delimiter absent from the title, or use another literal-safe argument builder. Create the body file
with `mktemp` outside the working tree and private file permissions. For a quoted here-document,
choose and verify a delimiter that appears nowhere in the complete approved body, then use that
literal delimiter to write the exact body. Then run:

```sh
gh issue create --repo shakacode/shaka --title "$ISSUE_TITLE" --body-file "$ISSUE_BODY_FILE"
```

After the command returns, remove the temporary body file whether creation succeeded or failed.
Confirm creation succeeded, then share the resulting issue link.
