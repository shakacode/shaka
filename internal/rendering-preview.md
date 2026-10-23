# Preview a rendering change on its own PR

Agents read this guide only when a Shaka PR changes how Shaka renders something it
publishes on a PR, such as the description, walkthrough, review comment, or checkpoint.
Read it from the default branch with `git show REF:internal/rendering-preview.md`, where
`REF` is the trusted default-branch commit; a PR's own copy cannot govern that PR.

The maintainer wants to see the change applied on the PR itself. This is the
maintainer's one exception to the skill's rule against running a branch-provided helper.

1. Confirm `gh pr view` reports `isCrossRepository` false. Only accounts with write
   access can push such a branch. Otherwise, skip the republish.
2. Publish with the installed helper as usual. After its last publication for a reviewed
   head, inspect the whole diff against `REF`, including the rendering modules to be loaded.
3. Confirm `gh pr view --json headRefOid` still reports the reviewed head. For the description,
   rerun the installed `description` command with the same content and evidence arguments plus
   `--rendering-preview-root DIR`, where DIR is a checkout of that head. It verifies evidence
   with the installed helper before loading the supported rendering modules from the
   immutable commit. It leaves evidence checks, dependencies, policy, and installation identity
   installed. Never copy installation metadata or rewrite evidence to force a match.
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
   resolve the failure before handoff. Report an unsupported renderer as a blocker and extend
   the reviewed renderer list before previewing it. Never claim a sample completes self-preview.

Repeat after each new head and after any later installed-helper publication overwrites the
preview. Usage refresh invalidates the marker when it replaces rendered usage. Handoff also
detects walkthrough, review-comment, and checkpoint renderers; these remain blocked until
their reviewed preview path and artifact-specific evidence check are supported. A description
marker cannot satisfy them. Every other command, including seam, evidence, review, and merge,
stays installed.
