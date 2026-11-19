# Structure documentation around using Shaka

Use this guide when writing or restructuring Shaka's product documentation.
The goal is for a new user to start a task, ask their agent for help, and judge the
resulting PR without first studying Shaka's workflow. The writing rules in
[AGENTS.md](../AGENTS.md#writing-in-this-repository) still apply.

## Check documentation destinations

`bin/check-docs-navigation` requires every product guide under `docs/` to appear
in `docs/sidebars.json`. Sources under `docs/` must not be symlinks; the published
files and directories must travel with the documentation tree.
Tracked symlink entries also fail when a checkout materializes them as plain files.
New Markdown outside the established documentation
locations fails validation until its destination is reviewed. The root
`README.gem.md` serves RubyGems, `contributing/` serves contributors, and
`internal/` and `eval/` hold development records.
The inventory covers `.md` and `.mdx` files regardless of extension case.
The site requires lowercase `.md`/`.mdx` extensions and excludes dot paths,
underscore paths and `planning/` folders. Move
product guides to visible `docs/` paths before enrolling them; move non-site
documents to their established destination instead.

Run the check in a Git checkout to exclude ignored dependencies. A source export
without Git metadata checks every Markdown file, including vendored dependencies.
Use a complete Git checkout with no skip-worktree paths, including sparse omissions.
Ignored local files cannot satisfy link targets under `docs/`.
Relative links use checked repository paths; use canonical paths rather than aliases.
Scanned source files must have real directory ancestors, including skill sources.
Use regular source files; dangling untracked aliases are ignored.
Use exact source-path casing. Front matter must not override publication IDs or
visibility with `id`, `draft`, `unlisted`, or YAML merge keys; use the checked paths
and sidebar, and keep unpublished writing outside `docs/`.
Start guide and directory names with a non-digit to avoid site ID rewriting.
The site reserves the root `changelog` ID for generated release notes; edit root
`CHANGELOG.md` instead, and use another source name for a guide.
Keep the root overview at `docs/README.md`; an authored `README.mdx` would collide
with the site's generated fallback.

Public guides and sidebar links must lead to human guidance. The check rejects
links into Shaka's skill Markdown, its YAML workflow instructions and project agent instructions.
Canonical `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` and `SKILL.md` names, including dot-suffixed
variants such as `AGENTS.override.md`, are reserved for agents regardless of case.
Agent Markdown and rules in host configuration directories, such as `.claude/`
and `.github/instructions/`, are agent destinations too. The canonical paths and
legacy control filenames are listed in `lib/shaka_docs/audiences.rb`.
Configuration data and installable workflow templates, including
`claude-code-review.yml`, remain linkable for setup. Citations of other projects'
skills remain available. Extensionless source paths under `skills/` or `.agents/`
are treated as agent targets, including directories and scripts.
Source citations use a commit, tag, or branch without
slashes so the check can distinguish the ref from the repository path. Slash-containing
refs require author and reviewer judgment. GitHub, raw GitHub and jsDelivr's `/gh/`
source layouts are recognized; other external source layouts require manual review.
Leading-slash links address public site routes.
Commonmarker parses Markdown including footnotes, Nokogiri extracts HTML links,
and Addressable normalizes URLs.
HTTP(S) links need a parsed authority. Prefer canonical `://host` spelling;
short forms such as `http:/example.com` fail instead of relying on browser recovery.
File and heading-anchor validation applies to Markdown links and images. Static
HTML navigation links, including image-map and SVG links, are checked for agent destinations.
Code examples and
unused reference definitions are not links. MDX-specific syntax and custom
components require manual review. Each guide's author and reviewer still determine its audience.

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
