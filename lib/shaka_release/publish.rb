# frozen_string_literal: true

require 'tmpdir'
require_relative 'approval'
require_relative 'preflight'
require_relative 'registry'
require_relative 'release_tag'
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
      @tag = ReleaseTag.new(root:, commit:, version:, env: @env)
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
      tagged = @tag.remote
      published = @registry.published_sha256(version)
      refuse "v#{version} on GitHub points at #{tagged}, not the approved commit" unless [nil, commit].include?(tagged)
      refuse "RubyGems has a different shaka #{version}; prepare a new version" unless
        [nil, @approval.gem_sha256].include?(published)
      @tag.check_source unless tagged
      [(:push_tag unless tagged), (:push_gem unless published), (:create_release unless release?)].compact
    end

    def push_tag
      @tag.push
      say "Pushed tag v#{version}."
    end

    def push_gem
      # Inherits the terminal so the person enters the RubyGems MFA code.
      unless system(@env, 'gem', 'push', '--host', Registry::HOST, @approval.gem)
        refuse 'gem push failed. If RubyGems already accepted this version, rerun publish in a few minutes; ' \
               'otherwise fix credentials or MFA and rerun.'
      end
      say "Pushed shaka #{version} to RubyGems."
    end

    def create_release
      Dir.mktmpdir('shaka-release-notes') do |directory|
        body = File.join(directory, 'notes.md')
        File.write(body, @approval.release_body)
        command = ['gh', 'release', 'create', "v#{version}", '--repo', REPOSITORY, '--verify-tag',
                   '--title', "shaka #{version}", '--notes-file', body, '--generate-notes']
        command << '--prerelease' if @approval.prerelease?
        run!(gh_env, *command)
      end
      say "Created the GitHub release v#{version}."
    end

    def install_check
      Dir.mktmpdir('shaka-release-install') do |home|
        env = @env.merge('GEM_HOME' => home, 'GEM_PATH' => home)
        run!(env, 'gem', 'install', 'shaka', '--version', version, '--no-document', '--remote', '--clear-sources',
             '--source', Registry::HOST,
             failure: 'RubyGems may not serve the new version yet; rerun publish in a few minutes')
        run!(env, File.join(home, 'bin/shaka'), '--help')
      end
      say "Installed shaka #{version} from RubyGems and ran shaka --help."
    end

    # A draft is not public, so it does not count as a published release.
    def release?
      output, error, status = Open3.capture3(gh_env, 'gh', 'release', 'view', "v#{version}", '--repo', REPOSITORY,
                                             '--json', 'isDraft')
      return false if !status.success? && error.include?('release not found')

      refuse "Cannot read the GitHub release: #{error.strip}" unless status.success?
      refuse "GitHub release v#{version} is a draft; publish or delete it, then rerun" if
        JSON.parse(output).fetch('isDraft')

      true
    end

    def commit = @approval.commit
    def version = @approval.version
    # Pins gh to github.com, where the tag is pushed, whatever host the shell selects.
    def gh_env = @env.merge('GH_HOST' => 'github.com')
    def say(message) = @out.puts(message)
  end
end
