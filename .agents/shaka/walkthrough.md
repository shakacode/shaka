# Walkthrough coverage for shakacode/shaka

Cover each item whose condition the change meets; skip the rest.

## Agent instructions

When the PR changes agent instructions, such as files under `skills/shaka/` or
`AGENTS.md`, say when each changed instruction file loads: on every task, or only
under its stated condition. Cite the word and byte deltas from
`bin/report-instruction-growth BASE` for the rendered workflow and entry point.

## Who enforces a rule

When the PR adds or changes a rule, say whether Ruby enforces it, with a code link
to the check, or only the agent does. For a workflow rule, match its entry in
`skills/shaka/config/enforcement.yml`.

## Settings

When the PR adds a setting or changes a default, link the changed lines in
`skills/shaka/config/defaults.yml` and the `.agents/shaka/config.yml` example. Say
what an existing repository has to do after merge, or that nothing changes for it.

## Predecessor reuse

When the PR designs workflow behavior, say what you checked in
`shakacode/agent-workflows`. Link what the change reuses or adapts at a commit and
name the material differences, or say that nothing there fit.
