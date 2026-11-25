# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

module Shaka
  # Codex reads AGENTS.md from CODEX_HOME even with --ignore-rules --ignore-user-config, and a
  # personal rule there can answer the review prompt instead of reviewing. The reviewer starts from
  # a temporary home that links only the sign-in file and the saved sessions, which usage reads.
  # Codex saves a refreshed sign-in through the link, so the user's own file stays current.
  module LocalReviewCodexHome
    SIGN_IN = 'auth.json'
    SESSIONS = 'sessions'

    # Yields the temporary home; the block returns the process result. A reviewer that survived
    # termination keeps its home, so a late sign-in save still reaches the user's file.
    def self.with_isolated(environment = ENV)
      home = Dir.mktmpdir('shaka-codex-home-')
      link(source(environment), home)
      result = yield home
    ensure
      FileUtils.remove_entry(home) if home && !survivor?(result)
    end

    # The variable and default CodexUsage reads; an empty value uses the default instead of
    # resolving to the working directory.
    def self.source(environment)
      value = environment['CODEX_HOME'].to_s
      File.expand_path(value.empty? ? '~/.codex' : value)
    end

    def self.link(source, home)
      link_sessions(source, home)
      sign_in = File.join(source, SIGN_IN)
      File.symlink(sign_in, File.join(home, SIGN_IN)) if File.exist?(sign_in)
    end

    # Without the link the session stays in the temporary home and usage reads UNKNOWN; the
    # review itself still runs.
    def self.link_sessions(source, home)
      FileUtils.mkdir_p(File.join(source, SESSIONS))
      File.symlink(File.join(source, SESSIONS), File.join(home, SESSIONS))
    rescue SystemCallError
      nil
    end

    def self.survivor?(result)
      result.is_a?(Array) && result.last.is_a?(LocalReviewProcess::CleanupError)
    end

    private_class_method :source, :link, :link_sessions, :survivor?
  end
end
