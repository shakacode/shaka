# Set up Shaka for your team

<a id="configure-a-repository"></a>
<a id="use-shaka-across-projects"></a>

Set up shared settings so people working in the same repository use the same
checks, reviewers, and merge choices. Use one Shaka installation across projects;
each repository keeps its own settings.

To try Shaka on your own first, choose **Just for me** in
[Start here](getting-started.md#2-set-up-your-project).

Examples use `/shaka`. In Codex, use `$shaka` instead.

<a id="before-you-start"></a>

## Required checks

Shaka uses the checks GitHub requires for the branch a PR targets. If GitHub
requires none, the agent can suggest checks to require in Shaka settings. Shaka
waits for those checks on tasks using those settings, including an explicit preview. GitHub does not enforce that
separate list when you merge there yourself.

You can use **Ask** without a required check. `auto` needs at least one.
See [required-check settings](settings.md#mergerequired_checks) and
[what happens if a check already fails](working-with-shaka.md#choose-a-merge-policy).

## Set up

Ask your agent:

```text
/shaka Set up Shaka for my team in this repository
```

The agent finds your existing checks, explains reviewer choices, and prepares a
separate setup PR. It starts with **Ask**, so you decide when work merges.
Review and merge the first setup PR yourself on GitHub under the existing branch
protection. After it merges, new tasks use those shared settings. To try the settings first, see
[preview a settings PR](settings.md#preview-settings-before-adopting-them).

For later changes, use [Choose your settings](settings-guide.md). See the
[built-in defaults](../skills/shaka/config/defaults.yml) and
[Shaka's own overrides](https://github.com/shakacode/shaka/blob/main/.agents/shaka/config.yml) for a working example.

## Files the agent prepares

| File | Purpose |
| --- | --- |
| `.agents/shaka/config.yml` | Your team's checks, reviewer choices, and merge settings |
| `.agents/shaka/bin/` | Scripts that connect Shaka to your existing setup and checks |
| `.agents/shaka.md` | A pointer to the settings for people browsing the repository |

Review the setup PR to see which files were added or updated. See the
[settings reference](settings.md) for optional files and exact settings.

<a id="add-hosted-claude-review"></a>

For an optional GitHub review job, see [hosted Claude review](settings.md#hosted-claude-review).

<a id="run-the-scripts-in-a-ci-container"></a>

If your CI uses a container, see [standard command scripts](settings.md#run-the-scripts-in-a-ci-container)
for checkout ownership and script setup.

### Show where validation time goes

A PR's [timings](reference/timings.md) can split each validation run into its
phases, such as tests and lint, so you can see which one to speed up. When Shaka
runs a script, `SHAKA_PHASE_LOG` names a file. Have the script append one JSON
line per phase:

```sh
start=$(date +%s)
status=0
bundle exec rspec || status=$?
echo "{\"phase\":\"tests\",\"duration_ms\":$(( ($(date +%s) - start) * 1000 ))}" >> "${SHAKA_PHASE_LOG:-/dev/null}"
[ "$status" -eq 0 ] || exit "$status"
```

The script records the phase even when the tests fail, then exits with their status.

Shaka keeps up to eight phases per run. A name starts with a lowercase letter,
then lowercase letters, digits, `-`, or `_`, up to 24 characters; Shaka skips a
line it cannot use. Shaka's own [`bin/validate`](https://github.com/shakacode/shaka/blob/main/bin/validate)
reports its four phases this way.
