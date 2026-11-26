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
    def self.with_isolated(environment = ENV, checkout: nil)
      home = Dir.mktmpdir('shaka-codex-home-')
      link(real_home(environment), home, checkout)
      result = yield home
    ensure
      FileUtils.remove_entry(home) if home && !survivor?(result)
    end

    # The user's own Codex home, which CodexUsage also reads. An explicit value is kept as given,
    # since expanding `..` after a symlink could name another directory; an empty one uses the default.
    def self.real_home(environment = ENV)
      value = environment['CODEX_HOME'].to_s
      return File.join(Dir.home, '.codex') if value.empty?

      File.absolute_path?(value) ? value : File.join(Dir.pwd, value)
    end

    def self.link(source, home, checkout)
      link_sessions(File.join(source, SESSIONS), home, checkout)
      sign_in = File.join(source, SIGN_IN)
      File.symlink(sign_in, File.join(home, SIGN_IN)) if File.exist?(sign_in)
    end

    # Without the link the session stays in the temporary home and usage reads UNKNOWN; the
    # review itself still runs. A sessions folder inside the reviewed checkout is never created or
    # linked, so a review writes nothing into the candidate.
    def self.link_sessions(sessions, home, checkout)
      return if inside?(sessions, checkout)

      FileUtils.mkdir_p(sessions)
      File.symlink(sessions, File.join(home, SESSIONS)) unless inside?(sessions, checkout)
    rescue SystemCallError
      nil
    end

    # Resolves through the deepest existing folder, so a link into the checkout counts as inside.
    def self.inside?(path, checkout)
      return false unless checkout

      existing = path
      existing = File.dirname(existing) until File.exist?(existing)
      resolved = File.join(File.realpath(existing), path.delete_prefix(existing))
      root = File.realpath(checkout)
      resolved == root || resolved.start_with?("#{root}/")
    end

    def self.survivor?(result)
      result.is_a?(Array) && result.last.is_a?(LocalReviewProcess::CleanupError)
    end

    private_class_method :link, :link_sessions, :inside?, :survivor?
  end
end
