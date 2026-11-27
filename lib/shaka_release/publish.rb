# frozen_string_literal: true

require 'tmpdir'
require_relative 'approval'
require_relative 'preflight'
require_relative 'registry'
require_relative 'shell'

module ShakaRelease
  # Publishes an approved release: tag, gem, GitHub release, then a clean install from RubyGems.
  # Each run reads what already exists and performs only the missing steps, so a rerun resumes.
  class Publish
    include Shell

    REPOSITORY = 'shakacode/shaka'
    LABELS = { push_tag: 'push the tag', push_gem: 'push the gem', create_release: 'create the GitHub release' }.freeze

    # `context` holds the `registry`, the subprocess `env`, and the `out` stream; tests replace them.
    def initialize(root:, approval:, dry_run: false, **context)
      @root = root
      @approval = Approval.new(approval)
      @dry_run = dry_run
      @registry = context.fetch(:registry) { Registry.new }
      @env = context.fetch(:env, {})
      @out = context.fetch(:out, $stdout)
    end

    def run
      @approval.check_files
      steps = missing_steps
      report(steps)
      return steps if @dry_run

      steps.each { send(it) }
      install_check
      say "Published shaka #{version}."
      steps
    end

    private

    def report(steps)
      say "shaka #{version} at #{commit}"
      labels = steps.map { LABELS.fetch(it) }
      say(steps.empty? ? 'Already published; checking the install.' : "To do: #{labels.join(', ')}, install check")
    end

    def missing_steps
      tagged = remote_tag
      published = @registry.published_sha256(version)
      refuse "v#{version} on GitHub points at #{tagged}, not the approved commit" unless [nil, commit].include?(tagged)
      refuse "RubyGems has a different shaka #{version}; prepare a new version" unless
        [nil, @approval.gem_sha256].include?(published)
      check_main unless tagged
      [(:push_tag unless tagged), (:push_gem unless published), (:create_release unless release?)].compact
    end

    # The tag is the first step users can see, so the approved commit must still be main.
    def check_main
      remote = git('ls-remote', '--exit-code', Preflight::REMOTE, 'refs/heads/main').split.first
      refuse 'remote main moved after approval; prepare and approve again' unless remote == commit
    end

    def push_tag
      local = local_tag
      refuse "local tag v#{version} points at another commit; delete it and rerun" if local && local != commit
      git('tag', '-a', "v#{version}", commit, '-m', "Release shaka #{version}") unless local
      git('push', Preflight::REMOTE, "refs/tags/v#{version}")
      say "Pushed tag v#{version}."
    end

    def push_gem
      # Inherits the terminal so the person enters the RubyGems MFA code.
      refuse 'gem push failed; rerun publish after fixing credentials or MFA' unless
        system(@env, 'gem', 'push', @approval.gem)
      say "Pushed shaka #{version} to RubyGems."
    end

    def create_release
      Dir.mktmpdir('shaka-release-notes') do |directory|
        body = File.join(directory, 'notes.md')
        File.write(body, @approval.release_body)
        command = ['gh', 'release', 'create', "v#{version}", '--repo', REPOSITORY, '--verify-tag',
                   '--title', "shaka #{version}", '--notes-file', body, '--generate-notes']
        command << '--prerelease' if @approval.prerelease?
        run!(@env, *command)
      end
      say "Created the GitHub release v#{version}."
    end

    def install_check
      Dir.mktmpdir('shaka-release-install') do |home|
        env = @env.merge('GEM_HOME' => home, 'GEM_PATH' => home)
        run!(env, 'gem', 'install', 'shaka', '--version', version, '--no-document',
             failure: 'RubyGems may not serve the new version yet; rerun publish in a few minutes')
        run!(env, File.join(home, 'bin/shaka'), '--help')
      end
      say "Installed shaka #{version} from RubyGems and ran shaka --help."
    end

    def release?
      _output, error, status = Open3.capture3(@env, 'gh', 'release', 'view', "v#{version}", '--repo', REPOSITORY,
                                              '--json', 'tagName')
      return true if status.success?
      return false if error.include?('release not found')

      refuse "Cannot read the GitHub release: #{error.strip}"
    end

    def remote_tag
      output = git('ls-remote', Preflight::REMOTE, "refs/tags/v#{version}", "refs/tags/v#{version}^{}")
      refs = output.lines.to_h { it.split.reverse }
      refs["refs/tags/v#{version}^{}"] || refs["refs/tags/v#{version}"]
    end

    def local_tag
      output, status = Open3.capture2(@env, 'git', '-C', @root, 'rev-parse', '--verify', '--quiet',
                                      "refs/tags/v#{version}^{commit}")
      status.success? ? output.strip : nil
    end

    def commit = @approval.commit
    def version = @approval.version
    def git(*) = run!(@env, 'git', '-C', @root, *)
    def say(message) = @out.puts(message)
  end
end
