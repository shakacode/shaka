# Preview a rendering change on its own PR

Agents read this guide only when a Shaka PR changes how Shaka renders something it
publishes on a PR, such as the description, walkthrough, review comment, or checkpoint.
Read it from the default branch with `git show REF:internal/rendering-preview.md`, where
`REF` is the trusted default-branch commit; a PR's own copy cannot govern that PR.

The maintainer wants to see the change applied on the PR itself. This is the
maintainer's one exception to the skill's rule against running a branch-provided helper.

A PR whose only changed publication files are those `RenderingPreview::INSTALLED` names skips
this procedure: a preview keeps them installed, so it cannot show their change. `handoff` owes
no preview for them and lists them as not previewed.

1. Confirm `gh pr view` reports `isCrossRepository` false. Only accounts with write
   access can push such a branch. Otherwise, skip the republish.
2. Publish with the installed helper as usual. After its last publication for a reviewed
   head, inspect the whole diff against `REF`, including the rendering modules to be loaded.
3. Confirm `gh pr view --json headRefOid` still reports the reviewed head. For the description,
   rerun the installed `description` command with the same content and evidence arguments plus
   `--rendering-preview-root DIR`, where DIR is a checkout of that head. It verifies evidence
   with the installed helper before loading every Ruby file in `skills/shaka/lib/shaka/publication/`
   from the immutable commit, each after the files it requires. It leaves evidence checks,
   dependencies, policy, and installation identity installed, and does not load the guard, write,
   and merge-warning files `RenderingPreview::INSTALLED` names; `handoff` lists any of those the PR
   changed. Head code still runs in the same process, so this is no boundary against the diff
   you inspected. Never copy installation metadata or rewrite evidence to force a match.
   Other affected artifacts use `skills/shaka/scripts/shaka` from a detached checkout of that
   head; review their rendering code before running it. Mixed workflow changes do not excuse
   skipping the supported description preview.
4. Inspect the actual PR description on GitHub at desktop and mobile widths: headings,
   diff totals and bucket paths, visible token cost, and expanded evidence and metadata.
   Record the result under verification. A fixture comment is supporting
   evidence and does not replace self-preview. Run the installed `handoff`; it requires the
   current-head preview marker for Shaka publication changes. For a review comment, confirm its last line is still the
   `REVIEWED` attestation that `merge` reads.
5. If preview, `handoff`, or attestation checks fail, restore the installed rendering and
   resolve the failure before handoff. Report an unsupported renderer as a blocker. A head
   that lacks an installed renderer, or whose files require each other in a cycle, is refused:
   rebase an older head or fix the cycle. A PR that deletes or renames a renderer cannot
   preview until the installation has that change. Never claim a sample completes self-preview.

Repeat after each new head and after any later installed-helper publication overwrites the
preview. Usage refresh invalidates the marker when it replaces rendered usage. Handoff also
detects walkthrough, review-comment, and checkpoint renderers; these remain blocked until
their reviewed preview path and artifact-specific evidence check are supported. A description
marker cannot satisfy them. Every other command, including seam, evidence, review, and merge,
stays installed.
