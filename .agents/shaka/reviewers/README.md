# Shaka reviewers

Files here add rules to the prompts Shaka's reviewing models receive. A reviewer gets
Shaka's built-in prompt, or the replacement a `prompt_file` setting names, then this
repository's applicable `AGENTS.md` files, then its file here. The reviewer is told that
a file here wins when it conflicts with the earlier questions and criteria, though it
cannot relax Shaka's safety rules or change what a reviewer must report. Put a rule for every agent in `AGENTS.md` and a rule for one reviewer here.

Shaka reads these files from the default branch, so a pull request cannot change the
rules it is reviewed by. A file Shaka does not list below is ignored.

<!-- shaka:conventions:begin -->
| File | Read by | When | Effect | If absent | Reference |
| --- | --- | --- | --- | --- | --- |
| `checkpoint.md` | Checkpoint reviewer | The "did we build the right thing?" check before merge | Added to the checkpoint prompt | The checkpoint prompt alone; an empty file counts as absent | [Settings](https://shaka.shakacode.com/docs/settings#checkpoint) |
<!-- shaka:conventions:end -->
