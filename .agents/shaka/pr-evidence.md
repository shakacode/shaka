# PR evidence for shakacode/shaka

## Rendered PR text

A change to how Shaka renders a PR description, walkthrough, or comment is a UI change.
Post before and after screenshots of the same content on the PR:

1. Inspect the head's rendering changes.
2. Render the content with the base and head code locally, calling the renderer as a
   function.
3. Convert each with `gh api markdown` (`mode=gfm`, `context=shakacode/shaka`).
4. Style the HTML with the `github-markdown-css` light and dark stylesheets.
5. Capture both themes at desktop width; these replace mobile captures.

Publish with the saved helper or `gh`, never the branch's commands. List the captures
in `verification`, or name the gap.
