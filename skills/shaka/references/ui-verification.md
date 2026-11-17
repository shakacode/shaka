# Verify a UI change

For UI changes, read this procedure before review and publication. Keep the workflow's validation,
review, publication, and Finish gates; these procedures supply the evidence
those gates require.

## UI changes

For UI changes, meaning anything a person sees on screen other than command-line output,
use the change by hand on the head you will push, and capture before and after screenshots
on desktop and mobile, adding a short video when interaction or timing matters. Inspect each capture
for the intended state and compare the whole affected view for unexpected changes.
Follow the [visual-evidence procedure](visual-diff.md) to choose and annotate
the lead image and keep the original captures available. Label intended and
unexpected changes, and explain any alignment limits. Exact pixel differences are optional
diagnostic evidence; put them in collapsed details when useful.
After a later commit that changes runtime behavior, repeat the manual pass and refresh
the affected captures and annotations, including any diagnostic differences.
Read the current public
[verification guide](https://github.com/shakacode/shaka/blob/main/docs/reference/pr-record.md#visual-evidence) for examples when deciding what evidence a
change needs. Follow this installed workflow if the current public guide differs.

## Publish UI evidence

Check captures for credentials as part of the workflow's privacy inspection.
Publish them with the saved helper's
`ui-check OWNER/REPO NUMBER --head SHA --content-file PATH` (GitHub CLI 2.99 or later). The
content JSON holds `identity`, the Explain writer fields; `body`, the verification note;
`captures`, each `PATH#ALT TEXT` (a video takes its path alone, since it has no alt text);
and optional `retire` and `earlier`. List in `earlier` the comment IDs of this PR's open UI
checks posted before this command, which it cannot recognize alone. To place a capture, reference its path in `body` as a Markdown image; an unreferenced one
is appended. The command adds the writer line and the heading that links
the head, confirms each capture uploaded, and folds this account's earlier UI checks.
Label captures with the tested revision.
For a newer head, `body` covers only what you checked at that head. The command carries
each earlier capture `body` leaves out into a collapsed history labeled with the revision
that captured it; history is not evidence for the new head. Name each view the newer
commits leave unchanged and refresh captures for every affected view. List an earlier
capture's URL in `retire` when a new capture replaces it. The history then marks it
replaced, or drops its check once none of that check's captures remain pending. Repeat a note recording why a capture could not be published; only captures are
carried. When the result lists `unavailable` folds, fold those with `review collapse`.
Once you resolve a preview for the description, whether through `deployment: auto` or a
URL you supply, repeat the manual pass against it, or record on the PR why not.

