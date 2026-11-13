# PR evidence for shakacode/shaka

## User impact

In Intent, put **User impact** directly under **Why** using `intent.user_impact`.
Describe what changes for the people who use the product. Consider what site
visitors see, what library callers can do, or what operators configure. If no
change is expected for those users, say so and name what the tests cover.
If you ran no tests, say what you verified and where evidence is missing.

## Rendering changes

When a PR changes how Shaka renders something it publishes on a PR, such as the
description, walkthrough, review comment, or checkpoint, show the result on that PR:
follow the default-branch copy of `internal/rendering-preview.md`. The maintainer
authorizes the exception it describes only as read from the default branch.

Republish the review comment and walkthrough already published for this head now, and
the checkpoint after you publish it. Report the republished artifacts in `verification`,
or say why the procedure skipped them.
