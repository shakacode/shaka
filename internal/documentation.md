# Structure documentation around using Shaka

Use this guide when writing or restructuring Shaka's product documentation.
The goal is for a new user to start a task, ask their agent for help, and judge the
resulting PR without first studying Shaka's workflow. The writing rules in
[AGENTS.md](../AGENTS.md#writing-in-this-repository) still apply.

## Give new users a way to start

Keep `README.md`, `docs/README.md`, `docs/getting-started.md`, and
`docs/shaka-in-pictures.md` focused on first use. Let each page serve its purpose:

| Page | What the reader needs |
| --- | --- |
| Root README | What Shaka is, why to try it, supported agents, and a direct path to a small task. |
| Docs overview | A short introduction and links to optional guides that also work on GitHub. |
| Getting started | Install, check the installation, choose individual or team setup, and run a task. |
| Shaka in pictures | A concrete practice task for someone new to branches and pull requests. |

Identify Shaka as a skill for AI coding agents before describing its benefits.
Explain the result the user gets and the decisions they still make, including who
controls merging. Keep the reasons to use Shaka alongside the first-task prompt.

Give the reader an installation prompt and a small task they can check. Show the
invocation for their coding agent. Retain the installation check, recovery help,
and useful diagram. Making the page shorter helps only if readers can still start
and recognize when they need help.

Introduce further capabilities through questions the user can ask their agent:

```text
How do I get Shaka to review an existing PR?
```

Offer a guide beside the prompt when it helps the reader make a choice. Let the
user choose between asking their agent and reading directly.

## Keep detail available when it becomes useful

Write each additional product guide around a user goal or question. Explain the
choice, its effect, and a concrete example. Link detailed options from the point
where someone needs them instead of repeating option tables on entry pages.

Keep reference pages readable by people and usable by their agents. A reader may
need to inspect a setting, understand a limitation, or recover without agent help.
Preserve requirements, safety boundaries, merge choices, and recovery information
in their authoritative guides when condensing an introduction.

Put execution instructions and helper syntax under `skills/shaka/`. Keep
development records and evaluation history under `internal/`. A product guide can
explain a limitation established by a trial without recounting the trial session.
Use the existing location for a rule or procedure rather than adding a second copy.

## Review the path to a useful result

Read the changed page as someone who has never used Shaka. For each sentence, ask
whether it helps them decide to try it, take the next action, understand the
result, or make a decision. Move useful lookup detail to its existing reference
home and remove repetition.

Check that the reader can find installation, a first task, and help without
opening every linked guide. The resulting PR should explain the change, its
verification, and what needs the user's attention. Describe where to look for
those answers rather than teaching the publication machinery.

Preserve existing URLs and heading anchors when reorganizing content. Check
navigation on GitHub as well as the docs site, where a sidebar may supply links
the Markdown page lacks.

Report what review established. Word counts show reading volume, link checks
show navigation, and an AI cold read is a simulation. Improved understanding or
successful onboarding needs observation of a new user; mark it unverified when
that evidence is absent.
