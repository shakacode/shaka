# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tempfile'
require 'tmpdir'

module Shaka
  # Codex reads AGENTS.md from CODEX_HOME even with --ignore-rules --ignore-user-config, and a
  # personal rule there can answer the review prompt instead of reviewing. The reviewer starts from
  # a temporary home that links only the sign-in file and the saved sessions, which usage reads.
  module LocalReviewCodexHome
    SIGN_IN = 'auth.json'
    SESSIONS = 'sessions'

    # Resolves CODEX_HOME the way CodexUsage does, so both find the same saved session.
    def self.with_isolated(environment = ENV)
      source = File.expand_path(environment.fetch('CODEX_HOME', '~/.codex'))
      Dir.mktmpdir('shaka-codex-home-') do |home|
        original = link(source, home)
        begin
          yield home
        ensure
          keep_refreshed_sign_in(source, home, original) if original
        end
      end
    end

    # Returns the sign-in file's content at launch, or nil when there is none to link.
    def self.link(source, home)
      link_sessions(source, home)
      sign_in = File.join(source, SIGN_IN)
      return unless File.file?(sign_in)

      File.symlink(sign_in, File.join(home, SIGN_IN))
      File.binread(sign_in)
    end

    # Without the link the session stays in the temporary home and usage reads UNKNOWN; the
    # review itself still runs.
    def self.link_sessions(source, home)
      FileUtils.mkdir_p(File.join(source, SESSIONS))
      File.symlink(File.join(source, SESSIONS), File.join(home, SESSIONS))
    rescue SystemCallError
      nil
    end

    # A token refresh that replaces the link instead of writing through it would otherwise leave
    # the user's own file holding a refresh token the provider has already rotated. The copy is
    # kept only when it is a complete JSON object and nothing else changed the real file meanwhile.
    def self.keep_refreshed_sign_in(source, home, original)
      copy = File.join(home, SIGN_IN)
      return if File.symlink?(copy) || !File.file?(copy)

      target = File.realpath(File.join(source, SIGN_IN))
      refreshed = File.binread(copy)
      return unless File.binread(target) == original && sign_in_object?(refreshed)

      replace(target, refreshed)
    rescue SystemCallError
      nil
    end

    def self.sign_in_object?(text)
      JSON.parse(text).is_a?(Hash)
    rescue JSON::ParserError, EncodingError
      false
    end

    def self.replace(target, content)
      temporary = Tempfile.create([SIGN_IN, '.tmp'], File.dirname(target))
      temporary.chmod(0o600)
      temporary.binmode
      temporary.write(content)
      temporary.close
      File.rename(temporary.path, target)
    ensure
      File.unlink(temporary.path) if temporary && File.exist?(temporary.path)
    end

    private_class_method :link, :link_sessions, :keep_refreshed_sign_in, :sign_in_object?, :replace
  end
end
