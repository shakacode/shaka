# frozen_string_literal: true

require 'fileutils'
require 'tempfile'
require 'tmpdir'
require_relative '../error'
require_relative '../usage/codex_usage'

module Shaka
  # Every path visited while resolving an absolute path one component at a time, so a symlink that
  # passes through a directory is seen even when the chain ends elsewhere.
  class CodexPathSteps
    MAX_LINKS = 40

    def initialize(path)
      @path = path
    end

    def to_a
      @visited = [@path]
      @parts = split(@path)
      @current = '/'
      @links = 0
      step until @parts.empty?
      @visited
    end

    private

    def step
      part = @parts.shift
      return if part == '.'

      candidate = part == '..' ? File.dirname(@current) : File.join(@current, part)
      @visited << candidate
      File.symlink?(candidate) ? follow(candidate) : @current = candidate
    end

    # A relative target resolves from the directory holding the link, which stays current.
    def follow(link)
      raise Error, 'Too many symlinks in the Codex sign-in path' if (@links += 1) > MAX_LINKS

      target = File.readlink(link)
      @parts = split(target) + @parts
      @current = '/' if target.start_with?('/')
    end

    def split(path) = path.split('/').reject(&:empty?)
  end

  # Codex reads AGENTS.md from CODEX_HOME even with --ignore-rules --ignore-user-config, and a
  # personal rule there can answer the review prompt instead of reviewing. The reviewer starts from
  # a temporary home that links only the user's sign-in file; Codex saves a refreshed sign-in through
  # the link. Its session stays in the temporary home, and usage gets a copy before cleanup.
  module LocalReviewCodexHome
    SIGN_IN = 'auth.json'

    # Yields the temporary home; the block returns the process result. A reviewer that survived
    # termination keeps its home, so a late sign-in save still reaches the user's file.
    def self.with_isolated(environment = ENV, checkout: nil)
      home = Dir.mktmpdir('shaka-codex-home-', scratch(checkout))
      link_sign_in(real_home(environment), home, checkout)
      result = yield home
    ensure
      FileUtils.remove_entry(home) if home && !survivor?(result)
    end

    # The session `codex exec --json` announced, copied outside the temporary home and the checkout,
    # or nil. The review itself has already succeeded, so a failed copy only leaves usage UNKNOWN.
    def self.keep_session(events, home, checkout: nil)
      session = CodexUsage.announced_session(events, environment: { 'CODEX_HOME' => home })
      return unless session

      copy = Tempfile.create(['shaka-codex-session-', '.jsonl'], scratch(checkout))
      IO.copy_stream(session, copy)
      copy.close
      copy.path
    rescue SystemCallError, IOError, Error
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

    # A sign-in reached through the reviewed checkout at any step is candidate content, not the
    # user's credentials, so it is never linked.
    def self.link_sign_in(source, home, checkout)
      sign_in = File.join(source, SIGN_IN)
      return unless File.file?(sign_in)
      return if through_checkout?(sign_in, checkout)

      File.symlink(File.realpath(sign_in), File.join(home, SIGN_IN))
    end

    # The system temporary directory, or /tmp when TMPDIR points into the checkout.
    def self.scratch(checkout)
      [Dir.tmpdir, '/tmp'].find { |dir| File.directory?(dir) && !through_checkout?(File.expand_path(dir), checkout) } ||
        raise(Error, 'No temporary directory outside the checkout for the Codex reviewer')
    end

    def self.through_checkout?(path, checkout)
      return false unless checkout

      roots = [File.expand_path(checkout), File.realpath(checkout)].uniq
      CodexPathSteps.new(path).to_a.any? { |step| roots.any? { |root| step == root || step.start_with?("#{root}/") } }
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

    private_class_method :link_sign_in, :scratch, :through_checkout?, :discard, :survivor?
  end
end
