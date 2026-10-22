# Shaka prompts

Each file here adds your own instructions to one of the prompts Shaka gives its
reviewers, named by the file. That prompt still applies in full, whether it is Shaka's
own or a replacement a `prompt_file` setting names: the reviewer reads it, then this
repository's applicable `AGENTS.md` files, then the file here. Your file wins when it
conflicts with the questions and criteria before it, though it cannot relax Shaka's
safety rules or change what the reviewer must report.

Put a rule for every agent in `AGENTS.md` and a rule for one prompt here. Shaka reads
these files from the default branch, so a pull request cannot change the rules it is
reviewed by. A file Shaka does not list below is ignored.

<!-- shaka:conventions:begin -->
| File | Adds to | Read by | When | If absent | Reference |
| --- | --- | --- | --- | --- | --- |
| `checkpoint.md` | [Checkpoint prompt](https://github.com/shakacode/shaka/blob/main/skills/shaka/config/post-implementation-prompt.md) | Checkpoint reviewer | The "did we build the right thing?" check before merge | No added instructions; an empty file counts as absent | [Settings](https://shaka.shakacode.com/docs/settings#checkpoint) |
<!-- shaka:conventions:end -->
