# Check Shaka with a canary run

Shaka runs a fixed task in a disposable repository after changes reach `main`.
Use the canary result to check whether a Shaka change broke PR publication
before relying on that version for real work.

```text
Show the latest Shaka canary result. Did it run the task, and what failed?
```

## Read a result

A green run means the sandbox PR opened and automatic checks passed. It does
not establish that the change was useful or the explanation was clear. Open the
PR and judge the result too. A red run links the failed check in its job log.
An unconfigured canary reports a notice and succeeds without running the task.

Manual runs test the selected ref. Push-triggered runs wait roughly an hour
between agent starts; a newer push cancels an older run. Do not merge sandbox
PRs: keeping the template unchanged lets each run repeat the same task.

<a id="set-it-up-once"></a>

Setup, credentials, and retention belong to
[the contributor guide](../contributing/development.md#set-up-the-canary).

<a id="read-a-canary-run"></a>
