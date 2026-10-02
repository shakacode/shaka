# frozen_string_literal: true

module Shaka
  # First-run help needs neither a repository nor a GitHub connection.
  module Welcome
    TEXT = <<~TEXT
      Give your coding agent a task. Get a tested, reviewed PR.

      In Codex, use $shaka; in Claude Code, Cursor, or OpenCode, use /shaka.
      In Pi, load the installed Shaka skill and give it the same request.

      Start small:
        $shaka Fix search when the query contains an apostrophe. Go.
      Set up a project:
        $shaka Configure this repository for Shaka. Keep merge policy ask.
      Resume a PR:
        $shaka https://github.com/OWNER/REPO/pull/123
      Check your setup:
        $shaka doctor

      Terminal commands:
        shaka doctor             Check this machine and repository; get setup advice.
        shaka doctor --root DIR  Check another checkout.
        shaka --help             List commands; add --help to a command for its options.

      Doctor lists supported reviewer CLIs and their installation guidance.
      A second provider can give independent review; extra CLIs are optional.
      Ask keeps the final merge with you. Auto merges after required checks and review.

      Start here: https://github.com/shakacode/shaka/blob/main/docs/getting-started.md
    TEXT

    def self.run
      puts TEXT
      0
    end
  end
end
