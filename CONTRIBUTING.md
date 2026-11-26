# Contributing

For a published guide, update `docs/sidebars.json` in the same PR. The docs site
syncs this navigation with the content; `bin/check-docs-navigation` rejects pages
missing from the sidebar and entries pointing to deleted pages. It also rejects
relative Markdown links, images and their heading anchors in `docs/` and `skills/` that do not resolve,
and rendered `shakacode/shaka` GitHub links on `main` to missing `docs/` pages or anchors.
Historical citations require review of their target contents. The separate literal-source
guard checks checkout targets throughout `skills/`, including code, regardless of ref.
Site-only pages and the global header/footer
remain in the site repository.

Validation also checks documentation destinations and keeps public guides and
sidebar links out of Shaka's agent instructions. See the
[documentation policy](internal/documentation.md#check-documentation-destinations).

Start with [developing Shaka](contributing/development.md) for local setup and
checks. Read [AGENTS.md](https://github.com/shakacode/shaka/blob/main/AGENTS.md) for repository constraints.

The [contributor index](contributing/README.md) covers implementation, packaging,
releases, and [evaluating changes](contributing/evaluating-changes.md).
[Development records](https://github.com/shakacode/shaka/blob/main/internal/README.md) hold requirements,
experiments, and dated adoption evidence.

For installing and using Shaka, see the [product documentation](docs/README.md).
