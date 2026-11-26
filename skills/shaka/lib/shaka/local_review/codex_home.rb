# frozen_string_literal: true

require 'fileutils'
require 'tempfile'
require 'tmpdir'
require_relative '../usage/codex_usage'

module Shaka
  # Codex reads AGENTS.md from CODEX_HOME even with --ignore-rules --ignore-user-config, and a
  # personal rule there can answer the review prompt instead of reviewing. The reviewer starts from
  # a temporary home that links only the user's sign-in file; Codex saves a refreshed sign-in through
  # the link. Its session stays in the temporary home, and usage gets a copy before cleanup.
  # CODEX_HOME and TMPDIR are the maintainer's own settings, so they are used as given.
  module LocalReviewCodexHome
    SIGN_IN = 'auth.json'

    # Yields the temporary home; the block returns the process result. A reviewer that survived
    # termination keeps its home, so a late sign-in save still reaches the user's file.
    def self.with_isolated(environment = ENV)
      home = Dir.mktmpdir('shaka-codex-home-')
      sign_in = File.join(real_home(environment), SIGN_IN)
      File.symlink(sign_in, File.join(home, SIGN_IN)) if File.file?(sign_in)
      result = yield home
    ensure
      FileUtils.remove_entry(home) if home && !survivor?(result)
    end

    # The session `codex exec --json` announced, copied outside the temporary home, or nil. The
    # review itself has already succeeded, so a failed copy only leaves usage UNKNOWN.
    def self.keep_session(events, home)
      session = CodexUsage.announced_session(events, environment: { 'CODEX_HOME' => home })
      return unless session

      copy = Tempfile.create(['shaka-codex-session-', '.jsonl'])
      IO.copy_stream(session, copy)
      copy.close
      copy.path
    rescue SystemCallError, IOError
      discard(copy)
      nil
    end

    # The user's own Codex home; an empty value uses the default, as Codex does. An explicit value is
    # kept as given, since collapsing `..` after a symlink could name another directory.
    def self.real_home(environment = ENV)
      value = environment['CODEX_HOME'].to_s
      return File.join(Dir.home, '.codex') if value.empty?

      File.absolute_path?(value) ? value : File.join(Dir.pwd, value)
    end

    def self.discard(copy)
      return unless copy

      copy.close unless copy.closed?
      FileUtils.rm_f(copy.path)
    rescue SystemCallError, IOError
      nil
    end

    def self.survivor?(result)
      result.is_a?(Array) && result.last.is_a?(LocalReviewProcess::CleanupError)
    end

    private_class_method :discard, :survivor?
  end
end
