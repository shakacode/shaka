# Which PRs merged with no change from a person: shakacode/shaka, 2026-09-21 to 2026-10-20

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on
2026-10-20. The maintainer asked it to find which merged pull requests (PRs)
went from "ready" to merged with no change asked for by a person, and what that
means for merging automatically. The agent collected the data, wrote the
scripts, and drafted the text. Codex and a fresh Claude session reviewed it
before publication.*

Sources are this repository's public PR data and counts from the maintainer's
local coding-agent chat logs. No chat text is quoted.

## Main results

- 201 of 309 PRs (65%) were one-shot. After the agent first said a PR was ready,
  no person commented on it on GitHub, and its content was the same when it merged.
- A person gave feedback on 65 PRs (21%): a GitHub comment, or a chat request
  that changed the PR. 64 of them changed docs for people or agent instructions.
  The 65th changed only this repository's Shaka settings file.
- No PR that left docs, agent instructions, and Shaka settings alone drew a
  person's feedback: 0 of 73 within [`merge.limits`](../settings.md#mergelimits),
  the size limits for a merge the agent submits. That held before and after
  2026-10-08, while docs and instruction PRs drew feedback 37% and then 18% of the
  time.
- What a PR changed predicted a person's feedback better than its size did. Of
  the 80 PRs with 50 or fewer changed lines, 9 still drew feedback.
- The agent's own review-effort rating missed PRs a person would comment on.
  People gave feedback on 13% of the docs and instruction PRs the agent rated 1
  or 2.
- On 28 PRs (9%), the agent changed the PR after a review bot reported a problem.
  An automatic merge has to keep waiting for `claude-review`, the hosted review
  that runs on each push.
- The data cannot separate the implementing model from the week it worked in.
  OpenAI models wrote most of the early PRs, when the maintainer commented most.

## How each PR was classified

- **Ready point:** the first checkpoint comment the agent published (241 PRs) or,
  before checkpoints existed, the first `awaiting-merge-approval` label (68 PRs).
  The checkpoint is a reviewer's verdict on whether the finished PR is worth
  merging. Both mean the agent handed the PR to the maintainer.
- **Content after the ready point:** the head commit at the ready point compared
  with the merged head. A rebase that left the PR's own diff the same counts as
  unchanged.
- **A person's comment:** a GitHub comment, review, or inline comment from a
  person after the ready point. Agents post through the maintainer's account, so
  posts with a `🤖` identity line or a Shaka marker were excluded. So were early
  agent posts that had neither, found by their fixed openings. Merge approvals,
  such as "Approved!", and answers to the agent's decision questions are not
  feedback.
- **A person's chat request:** a message the maintainer typed in the agent's chat
  after the ready point, on a PR whose content then changed. The agent read each
  one and dropped requests such as "resolve conflicts" or "merge it", and talk
  about other work in the same chat.

| Outcome | PRs | Share |
| --- | ---: | ---: |
| One-shot: no person's comment, content unchanged | 201 | 65% |
| A person commented on GitHub (4 of these PRs did not change) | 51 | 17% |
| A person's chat request changed the PR | 14 | 5% |
| The agent changed it after a review bot's finding | 28 | 9% |
| The content changed for another reason, such as a conflict fix | 15 | 5% |

One-shot PRs merged a median of 1.8 hours after the ready point. PRs with a
person's feedback merged a median of 15.6 hours after it.

Chat logs cover 136 of the 201 one-shot PRs. In none of them did a chat request
change the PR. In about 7, the maintainer asked for related work, and the agent
put it in a follow-up issue or PR.

## What the PR changed

"Docs for people" means `docs/` and `README.md`. "Agent instructions" means the
skill's reference files, `SKILL.md`, `workflow.yml`, packaged prompts, and
`AGENTS.md`.

| What the PR changed | PRs | One-shot | Person's feedback | Bot finding | Other change |
| --- | ---: | ---: | ---: | ---: | ---: |
| Docs for people and agent instructions | 91 | 34 (37%) | 39 (43%) | 13 | 5 |
| Docs for people, no agent instructions | 45 | 27 (60%) | 9 (20%) | 4 | 5 |
| Agent instructions, no docs for people | 95 | 68 (72%) | 16 (17%) | 8 | 3 |
| Code and tests, no docs or instructions | 48 | 47 (98%) | 0 | 0 | 1 |
| Tests, eval records, CI, internal notes, or Shaka settings | 30 | 25 (83%) | 1 (3%) | 3 | 1 |

- The one code PR that changed after its ready point was a conflict fix.
- The one PR with a person's feedback in the last row edited only
  `.agents/shaka/config.yml`.
- PRs that change both docs for people and agent instructions drew feedback more
  than twice as often as PRs that change one of them.

## Size

| Changed lines | PRs | One-shot | Person's feedback |
| --- | ---: | ---: | ---: |
| 1 to 50 | 80 | 66 (83%) | 9 (11%) |
| 51 to 200 | 98 | 71 (72%) | 18 (18%) |
| 201 to 500 | 67 | 38 (57%) | 16 (24%) |
| 501 to 999 | 49 | 24 (49%) | 14 (29%) |
| 1,000 or more | 15 | 2 (13%) | 8 (53%) |

- Larger PRs drew more feedback.
- Small PRs were not safe by size alone. Eight of the nine small PRs with a
  person's feedback touched docs or agent instructions. The ninth edited Shaka
  settings.

## The agent's own rating

From 2026-10-03, agents rated each PR's review effort from 1 to 5 in its
description; 106 PRs here have a rating.

| Agent's rating | PRs | Docs or instruction PRs with a person's feedback | Other PRs with a person's feedback |
| --- | ---: | ---: | ---: |
| 1 or 2 | 73 | 5 of 39 (13%) | 0 of 34 |
| 3 to 5 | 33 | 6 of 21 (29%) | 0 of 12 |

- Higher ratings went with more feedback.
- People gave feedback on docs and instruction PRs at every rating, and on no
  other PR at any rating. This supports computing a minimum rating from the
  changed paths, as [#757](https://github.com/shakacode/shaka/pull/757) proposes.
- The rated PRs drew feedback 10% of the time, against 18% for all PRs that
  reached the ready point in the same weeks. Compare the rating rule below with
  the path rules with that difference in mind.

## What people asked for

145 GitHub comments from a person came after a ready point. A keyword count gives
a rough split, and one comment can fall in more than one group:

- 60 asked for clearer, shorter, or better-aimed docs, such as "too verbose!" and
  "too hard to understand for new user!"
- 54 questioned the design or scope: why a change was needed, whether a file
  belonged elsewhere, or whether to split the PR.
- 12 were about names and terms.
- 7 asked for tests, verification, or an example.
- 43 matched none of these.

## Implementing model and provider

The model comes from the `🤖` line that opens each PR description. That line
names the agent that wrote the description, which is usually the implementer.

| Provider and models | PRs | Ready before 2026-10-08 | One-shot | Person's feedback | Docs or instruction PRs with a person's feedback |
| --- | ---: | ---: | ---: | ---: | ---: |
| Anthropic: claude-opus-5-5 | 178 | 42 | 121 (68%) | 33 (19%) | 33 of 134 (25%) |
| OpenAI: gpt-6.1-sol 90, gpt-6-sol 12, gpt-6-astra 10, others 7 | 119 | 85 | 70 (59%) | 32 (27%) | 31 of 92 (34%) |
| xAI: grok-4.7 | 10 | 10 | 8 (80%) | 0 | 0 of 5 |
| Unknown | 2 | 0 | 2 | 0 | 0 of 0 |

- OpenAI's higher rate matches when its PRs were written. 85 of its 119 PRs
  reached the ready point before 2026-10-08, when people gave feedback on 37% of
  docs and instruction PRs. In the later weeks the rate was 18%.
- People gave feedback on 7 of the 10 gpt-6-astra PRs, too few to judge the model.
- A fair comparison would give each model the same tasks, in a study of its own.

## Data and limits

- 378 PRs merged in the window, counted by merge date, and 309 are analysed. The
  other 69 merged with no checkpoint and no handoff label:
  - 58 were the maintainer's own PRs, most opened from 2026-09-20 to 2026-09-25,
    before the handoff label existed.
  - 9 were Dependabot updates.
  - 2 came from other ShakaCode members.
- One-shot means the PR merged as the agent first presented it. It does not show
  how closely the maintainer read the PR before merging it.
- Chat logs were found for 206 PRs. 65 one-shot PRs have none, so a chat request
  on one of them could have gone unseen. 22 PRs changed after the ready point with
  no chat log and no person's GitHub comment; some of them may have been steered
  in chat.
- One later fix named an earlier PR as its cause:
  [#645](https://github.com/shakacode/shaka/pull/645) fixed a failure from
  [#642](https://github.com/shakacode/shaka/pull/642). #642 merged without a
  handoff, so it is outside the 309.
- Comment text was read only for the maintainer, ShakaCode members, and the
  repository's trusted review bots. Comments by anyone else were counted from
  metadata alone.
- This repository's product is mostly docs and agent instructions. Other
  repositories will have a different mix.

## What this means for automatic merging

| Rule for merging without a person | Would have merged | Person's feedback | One-shot PRs it covers |
| --- | ---: | ---: | ---: |
| Only runtime code and tests, excluding merge, trust, settings, and install code | 33 | 0 | 33 of 201 |
| No docs, agent instructions, or Shaka settings, within `merge.limits` | 73 | 0 | 68 of 201 |
| No docs for people, within `merge.limits` | 152 | 10 (7%) | 130 of 201 |
| At most 50 changed lines | 80 | 9 (11%) | 66 of 201 |
| Agent rated review effort 1 or 2 (rated PRs only) | 73 | 5 (7%) | 58 of 201 |
| Any PR within `merge.limits` | 271 | 44 (16%) | 197 of 201 |

- Rules about which files changed did better than rules about size or the
  agent's rating.
- The second rule is the widest the data supports. It includes 4 PRs that touched
  trust code, 1 that touched merge code, and 11 that touched settings or install
  code. None drew a person's feedback, but that few PRs cannot show such changes
  are safe. Keeping them for a person stays a policy choice.
- 3 of those 73 PRs changed after a review bot's finding, so an automatic merge
  must still wait for the hosted review.

[#780](https://github.com/shakacode/shaka/issues/780) proposes path rules for
automatic merging, and [#757](https://github.com/shakacode/shaka/pull/757)
proposes computing a minimum review effort from the changed paths. These results
suggest they could become one setting. Each path would get a level of human
review from 0 to 5, and a PR would merge automatically only at level 0. Here,
code and tests would sit at 0, agent instructions above it, and docs for people
and Shaka settings at the top.

## Run the same study on your repository

Shaka has no built-in command for this study. Ask your agent for it as an
ordinary task. This report came from a request like this one:

```text
$shaka Study the PRs merged in the last four weeks. Find the ones that merged
with no change from a person after the agent said they were ready, compare them
with the ones a person changed, and recommend which kinds could merge
automatically.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
