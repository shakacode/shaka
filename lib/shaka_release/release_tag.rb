# frozen_string_literal: true

require_relative 'preflight'
require_relative 'shell'

module ShakaRelease
  # The annotated vVERSION tag on shakacode/shaka, read and pushed from the release checkout.
  class ReleaseTag
    include Shell

    def initialize(root:, commit:, version:, env: {})
      @root = root
      @commit = commit
      @name = "v#{version}"
      # Clears inherited repository overrides, as preflight does, so Git reads only this checkout.
      @env = env.merge(Shaka::WorkflowVersion::GIT_ENVIRONMENT)
    end

    # The commit the remote tag names, or nil when it does not exist.
    def remote
      output = git('ls-remote', Preflight::REMOTE, "refs/tags/#{@name}", "refs/tags/#{@name}^{}")
      refs = output.lines.to_h { it.split.reverse }
      refs["refs/tags/#{@name}^{}"] || refs["refs/tags/#{@name}"]
    end

    # The tag is the first step users can see, so the approved commit must still be main, and a
    # local tag of the same name must not point elsewhere. Dry runs check this too.
    def check_source
      main = git('ls-remote', '--exit-code', Preflight::REMOTE, 'refs/heads/main').split.first
      refuse 'remote main moved after approval; prepare and approve again' unless main == @commit
      refuse "local tag #{@name} points at another commit; delete it and rerun" unless [nil, @commit].include?(local)
      refuse "local tag #{@name} is not annotated; delete it and rerun" if local && !annotated?
    end

    def push
      check_source # again, just before the push, to narrow the window since the first check
      git('tag', '-a', @name, @commit, '-m', "Release shaka #{@name.delete_prefix('v')}") unless local
      # push.followTags could otherwise publish other local tags alongside this one.
      git('push', '--no-follow-tags', Preflight::REMOTE, "refs/tags/#{@name}")
    end

    private

    def local
      return nil unless system(@env, 'git', '-C', @root, 'rev-parse', '--verify', '--quiet', "refs/tags/#{@name}",
                               out: File::NULL)

      git('rev-parse', '--verify', "refs/tags/#{@name}^{commit}").strip
    rescue Shaka::Error
      refuse "local tag #{@name} does not name a commit; delete it and rerun"
    end

    def annotated? = git('for-each-ref', '--format=%(objecttype)', "refs/tags/#{@name}").strip == 'tag'

    def git(*) = run!(@env, 'git', '-C', @root, *)
  end
end
