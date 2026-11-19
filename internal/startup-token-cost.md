# Startup token cost

A development record of what Shaka's startup text costs in model tokens, measured at
each release, with one comparison against popular skill libraries for context. Claude
Code running Claude Opus 5.5 took the first measurements on 2026-11-16 and 2026-11-17
at the maintainer's request. The maintainer chose to keep the record internal instead of
publishing an article. The figures need context that a docs reader would not have.

## Where it stands at `f88fd8e`, 2026-11-17

`f88fd8e` has the same startup text as the log's first two rows.

- Invoking Shaka loads `SKILL.md` and the workflow that `shaka workflow` prints, 12,538
  words. Claude Code with Claude Opus 5.5 counts about 30,000 tokens; Codex with
  GPT-6.1 Sol counts about 20,100.
- Shaka's skill listing adds 60 Claude tokens to every session.
- Claude counts about 2.4 tokens per word of this text, against 1.6 for GPT-6.1 Sol.
- At Opus 5.5 API rates, writing the text to the prompt cache costs about $0.15 once
  per task. Re-reading it costs about $0.006 per later turn. In one measured session of
  271 turns and $36, re-reading it came to about $1.60, or 4 to 5%.
- It fills 3% of a 1M-token context window.
- Decision: no restructuring now. Measure at each release and act if the trend or an
  observed effect calls for it.

## Where the words are

The rendered workflow at `f88fd8e` has 12,251 words, by phase. The rows leave out the
workflow's title and its short Code quality section, 54 words between them.

| Phase | Words | Share |
| --- | ---: | ---: |
| Intake | 1,149 | 9% |
| Plan | 1,335 | 11% |
| Implement | 606 | 5% |
| Verify | 1,752 | 14% |
| Explain | 3,522 | 29% |
| Review | 635 | 5% |
| Finish | 2,074 | 17% |
| Always | 1,124 | 9% |

The rendered workflow grew from 10,610 words after the
[conditional loading change](conditional-workflow-loading.md) to 12,057 by 2026-11-16,
about 14% in a month.

The largest single lever is Explain, mostly the description and walkthrough publication
contract. A pointer that the agent follows at its first publication would keep about
8,000 Claude tokens off every earlier turn. The saving is roughly $0.25 per task at
today's rates. Moved instructions can change what agents do, so a change like that needs
live runs before it ships.

## Compared with other skill libraries

On 2026-11-17, a one-time script counted Shaka and the five most-starred skill libraries
on GitHub the same way. Counts are Claude Opus 5.5 / GPT-6.1 Sol tokens. The comparison
counts every skill body without its frontmatter, so its Shaka figure is about 100 tokens
below the log's, which includes `SKILL.md` frontmatter.

This table is a dated snapshot. The script was dropped to save its upkeep; it is
[`eval/bin/skill-library-tokens` at `e3fc600`](https://github.com/shakacode/shaka/blob/e3fc6004311361498036784e5ace0e6c0004fba7/eval/bin/skill-library-tokens).
Codex's logs for this run show one answer per text and no tool calls. A rerun should send
other libraries' text only to Claude Code, as that version does, for the reason under
[How to measure](#how-to-measure).

| Library | Commit | Every session | Median skill | Largest skill |
| --- | --- | ---: | ---: | ---: |
| Shaka | `f88fd8e` | 60 / 36 | 29,949 / 20,068 | 29,949 / 20,068 |
| [mattpocock/skills](https://github.com/mattpocock/skills) | `5863806` | 1,449 / 923 | 1,085 / 735 (`tdd`) | 4,050 / 2,771 (`wayfinder`) |
| [obra/superpowers](https://github.com/obra/superpowers) | `22f0b46` | 2,086 / 1,300 | 2,910 / 1,894 (`finishing-a-development-branch`) | 6,271 / 4,282 (`executing-plans`) |
| [anthropics/skills](https://github.com/anthropics/skills) | `e4bb5d9` | 3,266 / 2,066 | 4,137 / 2,385 (`mcp-builder`) | 40,575 / 26,384 (`claude-api`) |
| [garrytan/gstack](https://github.com/garrytan/gstack) | `5dcd76b` | 2,401 / 1,487 | 8,446 / 5,362 (`setup-deploy`) | 34,129 / 21,289 (`design-review`) |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | `39b723c` | 3,618 / 2,293 | 4,851 / 3,202 (`git-workflow-and-versioning`) | 7,653 / 5,064 (`constraint-driven-development`) |

- One Shaka invocation covers a whole delivery, from plan to merge handoff. Other
  libraries load a skill per step, so compare a Shaka invocation with the skills a
  delivery runs, not with one skill.
- Two delivery chains are estimates from word counts and each library's measured tokens
  per word, not counts. Which skills make up a delivery is a judgment call about another
  project's workflow.
  - Superpowers, about 25,000 Claude tokens: brainstorming, writing-plans,
    subagent-driven-development, test-driven-development, verification-before-completion,
    requesting-code-review, and finishing-a-development-branch.
  - gstack, about 74,000: spec, review, qa, verify, and ship.
- Shaka pays its cost up front, so early turns carry it too. The others pay as each
  skill runs.
- Superpowers' session-start hook injects its `using-superpowers` skill into every
  session; that is more than half of its every-session count.
- Claude counted 1.46 to 1.73 times as many tokens as GPT-6.1 Sol for every text, and
  1.98 to 3.10 tokens per word. Text with code, paths, and tables costs more per word.

What each count includes:

- **Every session:** one `- name: description` line per installed skill and command,
  plus any text a session-start hook injects. Real hosts format and shorten the listing
  their own way, so these are comparable but approximate.
- **Median and largest skill:** the skill body after its frontmatter. Files a skill opens
  only when needed, such as references, sections, or Shaka's conditional procedures, are
  left out.
- **What each install registers**, read from its manifest. Only Superpowers registers a
  hook that injects text.
  - Matt Pocock's plugin: 27 skills.
  - Superpowers: every `skills/*/SKILL.md`, 15 skills.
  - Anthropic's marketplace: 19 skills across five plugins.
  - gstack: its router and 63 linked skills.
  - Addy Osmani's plugin: 25 skills and 9 commands.

The comparison used about 233,000 Claude and 375,000 Codex tokens of plan quota and took
two minutes.

## How to measure

`bin/report-instruction-growth --tokens` uses Claude Code and Codex with the accounts they
are signed in to; no API keys. Each CLI answers a one-line prompt with and without the
text, and the difference in reported input tokens is the text's cost.

- At each release, the version PR runs `bin/report-instruction-growth --tokens
  PREVIOUS_TAG` and adds a row to the log below. It costs about 75,000 Claude and 85,000
  Codex tokens when the text changed.
- Compare each CLI's own prompt (`cli_prompt`) with the log. A jump means the CLI changed
  what it loads, and counts from different CLI versions may not compare.
- Claude Code runs with no tools. Codex has no switch that removes all of its tools. On
  2026-11-17, with its shell tools off, Codex could still search the web, view a local
  image, and call the apps connected to its account. The count now also turns off
  connected apps, web search, and image viewing. Codex 0.170.0 still lists others, such
  as sub-agents and image generation, so send it only Shaka's own text. A run that uses
  a tool counts as `UNKNOWN`.
- Turning Codex's tools off changes its own prompt: about 15,190 tokens with every tool,
  14,551 without its shell, and 10,933 with the current set. `65e0066`'s startup text
  counted 20,171 GPT tokens under all three.
- Claude counts of the same text vary by about 50 tokens between runs: `65e0066`'s text
  counted 30,151, 30,104, and 30,115. Codex counts varied by at most 2.

## Does the size matter?

Nothing yet measures whether the startup text's size changes what agents do. When a
change slims the workflow noticeably, note it in the log. Then compare outcomes the
repository already records, such as review findings per PR and the timings report,
across PRs before and after it. Without such a comparison, a smaller count shows only
a lower cost.

## Log

Startup text is `SKILL.md` plus the rendered workflow. Each row names the `main` commit
whose startup text it counted; at a release, that is the commit the version PR starts
from. Token counts exclude each CLI's own prompt, shown separately. Words and counts come
from the renderer of the commit that
ran the report, so a renderer change moves them too: on 2026-11-17 the current renderer
gave `f2441b6` 12,251 words and 30,051 Claude tokens.

| Date | Startup text at main | Workflow words | Claude Opus 5.5 | GPT-6.1 Sol | Claude CLI prompt | Codex CLI prompt | Note |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 2026-11-16 | `f2441b6` | 12,057 | 30,014 | 20,109 | 4,227 | 15,193 | First measurement, PR #1200 |
| 2026-11-17 | `5ffb304` | 12,057 | 30,012 | 20,109 | 4,231 | 15,191 | Same text as the row above; shows run-to-run noise |
| 2026-11-17 | `65e0066` | 12,289 | 30,151 | 20,171 | 4,229 | 15,191 | +100 Claude and +62 GPT against `f2441b6`, counted together |
