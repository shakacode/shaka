# Choose human review floors

Read this only when a maintainer asks to choose, change, or explain
`pr_description.human_review_floors`, or a description refusal names a floor they dispute.

## How Ruby applies the floors

- `description` reads the list from the trusted settings at `--ref`; the candidate branch's
  copy never applies. With no readable settings, the shipped defaults in
  `skills/shaka/config/defaults.yml` apply.
- A repository list replaces the default list entirely. `[]` turns floors off.
- Each floor has `level` (1 to 5), `reason` (shown in the description), and at least one of
  `paths` or `words`; `except` is optional.
- A file matches a floor when a `paths` glob matches it, or when one of `words`, or the word
  plus a trailing s, is a folder or file name token on its path, and no `except` glob matches
  it. Words match in any case; write each as one token of letters and digits, since a word
  containing punctuation never matches. Tokens split on punctuation and CamelCase, so `AuthService.ts`, `auth_token.rb`, and
  `lib/oauth/x.rb` all hold auth.
- `except` removes a file from its own floor only. Another floor can still match it.
- Globs use `File.fnmatch` with `FNM_PATHNAME`, `FNM_EXTGLOB`, and `FNM_DOTMATCH`: `**/` spans
  folders, `dir/**/*` matches everything under `dir`, and a trailing `dir/**` does not cross `/`.
- A renamed file counts under both names. The PR's floor is the highest level any changed
  file matches; the first matching file is the one the description names.
- A rating below the floor refuses publication. Ruby never raises the rating itself.

## Propose floors

1. Read the current list: the repository's `pr_description.human_review_floors`, or the
   shipped defaults when it has none.
2. List the repository's top-level folders and where it keeps code, docs, generated files,
   workflows, deployment, and settings. Note which docs serve external users and which serve
   agents or the team.
3. Ask the maintainer which changes they review most closely and which they skim, in concrete
   paths, with your proposed level for each. Recommend levels from what a mistake could reach:
   external users, every task an agent runs, merge or release authority, or only the author.
4. Draft the full list, since it replaces the defaults. Keep shipped floors the maintainer
   does not reject. Put each floor's `except` beside the globs it narrows, and check that it
   does not remove a file the same floor's `paths` was meant to cover; a broader `except`
   silently drops it to a lower floor.
5. Before proposing, compute the floor for the changed files of about ten recent merged PRs
   and show the maintainer each PR's number, its current rating, and the new floor. Save the
   draft list as YAML (`FLOORS`) and run, with the installed helper's `lib` as `LIB`:

   ```bash
   gh pr view NUMBER --json files --jq '.files[].path' |
     ruby -I "$LIB" -ryaml -rshaka/publication/review_effort_floor \
       -e 'p Shaka::ReviewEffortFloor.for(STDIN.read.split("\n"), YAML.safe_load_file(ARGV[0]))' FLOORS
   ```

   Point out PRs the list would hold at 4 or 5 and ask whether that matches their intent.
6. Publish the change as its own settings PR through the migration flow, and list the
   `shaka install --update` step for every installation as an after-merge step when the
   repository did not set this key before.
