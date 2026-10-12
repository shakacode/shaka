# Guided documentation review replay, #485

These are four agent trials of the
[guided documentation review](../../skills/shaka/references/guided-documentation-review.md),
reached through the skill entry point. None is an observed maintainer session, so
none shows that a person finds the pacing or the explanations readable.
[Issue #485](https://github.com/shakacode/shaka/issues/485) still asks for that session.

## Setup

The first two trials reviewed merged [#420](https://github.com/shakacode/shaka/pull/420):
base `4aac52c2`, head `b0dd4697`, merge commit `64cf0604`. By then
[#425](https://github.com/shakacode/shaka/pull/425) and
[#426](https://github.com/shakacode/shaka/pull/426) had also merged, and the trial
clone sat at `4e343485` on `main`.

Each trial was a fresh `claude -p` session in a separate clone whose push URL was
disabled. The first prompt named a copy of the candidate `SKILL.md` kept outside the
clone and gave the arguments `Review docs with me:` followed by the target. Read,
search, edit, and write tools were allowed, with `git` and read-only `gh pr` and
`gh issue` commands. Commands that write to GitHub were not allowed, so the trials show
no attempt to publish, not restraint with publication available.

The model was `sonnet`; the CLI reported `claude-sonnet-5`. Effort was not reported.

## First trial: five turns

This trial used an earlier draft of the procedure. The CLI reported 64 turns and $3.02
across the five prompts.

| Prompt | Observed |
| --- | --- |
| The review request | Read `SKILL.md`, then the procedure. Never ran the `workflow` command. Pinned #420's base, head, and merge commit, and said it was not reviewing today's `main`. Listed four topics and presented only the first. |
| A wording correction and “what would I actually type?” | Adopted the wording, answered with the two example prompts from the #420 documents, and labeled the trigger an agent instruction. Stayed on topic 1. |
| `continue` | Presented topic 2 only and reused the accepted wording. |
| “Skip topic 3 and do the opening_check topic. Is that still how it works today?” | Skipped as asked. Described the behavior at #420, then the behavior on `main` after #425, citing the code at each revision. |
| “That's enough for today. Wrap up.” | Listed the agreed wording, two verified findings, and the topic it had not covered. Started no task. |

It reported one mismatch between a document and its target, which holds at `b0dd4697`:
`docs/expected-experience.md` line 34 links the text “individual setup procedure” to a
heading that still reads “Try Shaka privately in one clone”. It left the choice of
which side to change to the maintainer and proposed no wording.

After every turn `git status --short` was empty and the clone still pointed at
`4e343485`. This does not rule out an edit that was reverted.

Two rules were not followed:

- It read implementation files from the working tree, which held `main`, not #420's head.
- It named files and line numbers without commit-pinned links.

The procedure now says to read at the pinned revision and to link with a URL that
contains the full commit SHA.

## Second trial: the revised procedure

A new session repeated the first prompt against the revised procedure. The CLI
reported 40 turns and $1.91.

| Question | Observed |
| --- | --- |
| Map and at most one topic? | Yes. Four topics listed, one presented, ending with a question. |
| Read at the pinned revision? | Yes. Its file reads were `git show`, `git grep`, and `git diff` against `b0dd4697`. |
| Commit-pinned evidence? | Yes. It linked `configuration.rb#L32-L43` at the full head SHA; those lines hold the cited `resolve_source` method. Two other claims were checked without a link. |
| Labeled claims? | Partly. One claim was labeled enforced by code. It marked unchanged sections as not re-derived. |
| Left the clone unchanged? | Yes, by the same two checks. It tried to extract #420's head into a temporary directory outside the clone; no such directory existed afterward. |

## Third trial: a documentation path

Local review of `4cbf9278` found that the path rule pinned a commit while the next rule
forbade reading the working tree, so an uncommitted draft could not be reviewed. The
procedure now reviews the file as it is in the checkout. A new session reviewed
`docs/faq.md` after one invented sentence was appended to it and left uncommitted. The
CLI reported 28 turns and $0.92.

| Question | Observed |
| --- | --- |
| Named the commit and the uncommitted change? | Yes. It named `4e343485` and the one-line addition, and placed that line in its last topic. |
| Map and at most one topic? | Yes. Seven topics listed, one presented, ending with a question. |
| Minimal prompt, labels, and commit-pinned evidence? | Yes. It quoted the guide's two-line prompt, labeled one claim enforced by code, and linked two files at the full commit SHA. |
| Left the clone unchanged? | Yes. `git status --short` showed only the appended sentence. |

The session ended before the topic holding the invented sentence, so its handling of
that claim was not observed.

## Fourth trial: an open PR missing from the clone

Local review of `9132051e` found no rule for a pinned commit the clone lacks. The
procedure now says to fetch it without checking it out. A new session reviewed open
[#489](https://github.com/shakacode/shaka/pull/489), whose head `d29471cf` was absent
from the clone. The CLI reported 37 turns and $1.51.

| Question | Observed |
| --- | --- |
| Reached the head without changing the checkout? | Yes. It ran `git fetch origin pull/489/head`; afterward the clone was still detached at `4e343485` with an empty `git status --short`. |
| Pinned head and comparison base? | Yes. It used the merge base `9eb2c3a1` and said why it differed from the base GitHub recorded. |
| Map and at most one topic? | Yes. The PR changes one section, so it listed and presented one topic, ending with a question. |
| Checked claims at the head? | Yes. Four claims were labeled enforced by code with links at the full head SHA, and one sentence was reported as not covering a case a test asserts. |

It wrote copies of two file versions to its session's temporary directory, outside the
clone, to compare them. The rule it ran under said “do not switch branches or extract
files”, so it did not follow that rule as written. The rule now names what it protects:
do not switch branches or write to the checkout.

## Limits

- Four sessions on one model, two PRs, and one path. Another run could differ.
- No person judged the readability or pacing. The author assessed both by reading transcripts.
- The later trials ran one turn each, so the pause, question, and close behavior rest
  on the first trial's draft. The second trial's procedure is the text at `4cbf9278`,
  the third's the text at `9132051e`, and the fourth's the text at `7b41e41a`. No trial
  ran the final wording of the checkout rule.
- The first trial's only minimal prompts came after the user asked for one. The second
  trial mentioned the guide's example prompts without showing one.
- #426 did not come up. The later-change evidence covers #425 only.
- An open PR whose head moves, a PR from a fork, an untracked file, and a request to reorder beyond one
  skip were not exercised.
- The skill copy was named in the prompt. A host invoking an installed
  `$shaka Review docs with me:` was not exercised; the installed skill cannot route
  there until this change ships.
- No session ran the entry point's `update-check`.
