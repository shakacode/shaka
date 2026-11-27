# frozen_string_literal: true

require 'digest'
require 'json'
require 'stringio'
require_relative '../../lib/shaka_release/publish'

# Stand-in `gh` and `gem` scripts that record what publication did in FAKE_STATE.
module ReleaseFakeCommands
  FAKE_GH = <<~RUBY
    state = ENV.fetch('FAKE_STATE')
    release = File.join(state, 'release')
    case ARGV.first(2)
    when %w[release view]
      abort 'HTTP 502' if File.exist?(File.join(state, 'gh_fails'))
      abort 'release not found' unless File.exist?(release)
      record = JSON.parse(File.read(release))
      puts JSON.generate('isDraft' => File.exist?(File.join(state, 'draft')), 'body' => record['body'].to_s,
                         'isPrerelease' => Array(record['args']).include?('--prerelease'))
    when %w[release create]
      notes = ARGV[ARGV.index('--notes-file') + 1]
      File.write(release, JSON.generate('args' => ARGV, 'body' => File.read(notes), 'host' => ENV['GH_HOST']))
    end
  RUBY

  FAKE_GEM = <<~RUBY
    state = ENV.fetch('FAKE_STATE')
    case ARGV.first
    when 'push'
      abort 'push refused' if File.exist?(File.join(state, 'push_fails'))
      File.write(File.join(state, 'registry'), Digest::SHA256.file(ARGV.last).hexdigest)
      File.write(File.join(state, 'pushes'), "\#{ARGV.join(' ')}\n", mode: 'a')
    when 'install'
      abort 'not found' if File.exist?(File.join(state, 'install_fails'))
      bin = File.join(ENV.fetch('GEM_HOME'), 'bin')
      FileUtils.mkdir_p(bin)
      File.write(File.join(bin, 'shaka'), "#!/bin/sh\necho usage\n")
      File.chmod(0o755, File.join(bin, 'shaka'))
      File.write(File.join(state, 'installs'), "\#{ARGV.join(' ')}\n", mode: 'a')
    end
  RUBY
end

# A release checkout with a local bare remote, and stand-in `gh`, `gem`, and RubyGems that
# record what publication did in a state directory.
module ReleasePublishFixture
  # Reads what the stand-in `gem push` recorded, as the RubyGems API would.
  class FakeRegistry
    def initialize(state) = @state = state

    def published_sha256(_version)
      path = File.join(@state, 'registry')
      File.exist?(path) ? File.read(path) : nil
    end
  end

  def setup
    @directory = Dir.mktmpdir('release-publish')
    @state = File.join(@directory, 'state')
    @root = File.join(@directory, 'source')
    [@state, @root].each { FileUtils.mkdir_p(it) }
    create_repository
    @env = { 'PATH' => "#{fake_bin}:#{ENV.fetch('PATH')}", 'FAKE_STATE' => @state }
    @approval = write_approval('1.2.0')
  end

  def teardown = FileUtils.remove_entry(@directory)

  private

  def publish(dry_run: false, out: StringIO.new)
    ShakaRelease::Publish.new(root: @root, approval: @approval, dry_run:, env: @env, out:,
                              registry: FakeRegistry.new(@state)).run
  end

  def assert_refused(message)
    error = assert_raises(Shaka::Error) { publish }
    assert_includes error.message, message
  end

  def state(name) = File.join(@state, name)
  def release_record = JSON.parse(File.read(state('release')))

  def create_repository
    git('init', '-q', '-b', 'main')
    File.write(File.join(@root, 'README.md'), "release\n")
    git('add', '.')
    commit('Release')
    @commit = git('rev-parse', 'HEAD').strip
    remote = File.join(@directory, 'origin.git')
    git('clone', '-q', '--bare', @root, remote)
    git('remote', 'add', 'origin', remote)
    git('config', "url.#{remote}.insteadOf", ShakaRelease::Preflight::REMOTE)
  end

  def advance_main
    File.write(File.join(@root, 'README.md'), "next\n")
    commit('Next')
    git('push', '-q', 'origin', 'HEAD:refs/heads/main')
  end

  def write_approval(version, gate: { 'status' => 'passed', 'records' => [] })
    @gem = File.join(@directory, "shaka-#{version}.gem")
    notes = File.join(@directory, 'RELEASE_NOTES.md')
    File.write(@gem, "gem #{version}")
    File.write(notes, "Fixes things.\n")
    path = File.join(@directory, 'approval.json')
    File.write(path, JSON.generate('status' => 'ready_for_approval', 'commit' => @commit, 'version' => version,
                                   'gem' => @gem, 'gem_sha256' => Digest::SHA256.file(@gem).hexdigest,
                                   'notes' => notes, 'notes_sha256' => Digest::SHA256.file(notes).hexdigest,
                                   'behavior_gate' => gate))
    path
  end

  def push_annotated_tag(target = 'HEAD')
    git('-c', 'user.name=T', '-c', 'user.email=t@example.com', 'tag', '-a', 'v1.2.0', target, '-m', 'Tag')
    git('push', '-q', 'origin', 'refs/tags/v1.2.0')
  end

  def remote_tag(version = '1.2.0') = git('ls-remote', 'origin', "refs/tags/v#{version}^{}").split.first

  def fake_bin
    bin = File.join(@directory, 'bin')
    FileUtils.mkdir_p(bin)
    { 'gh' => ReleaseFakeCommands::FAKE_GH, 'gem' => ReleaseFakeCommands::FAKE_GEM }.each do |name, body|
      File.write(File.join(bin, name), "#!#{RbConfig.ruby}\nrequire 'json'\nrequire 'digest'\n" \
                                       "require 'fileutils'\n#{body}")
      File.chmod(0o755, File.join(bin, name))
    end
    bin
  end

  def commit(message)
    git('-c', 'user.name=Release Test', '-c', 'user.email=test@example.com', 'commit', '-qam', message)
  end

  def git(*)
    output, error, status = Open3.capture3('git', '-C', @root, *)
    assert_predicate status, :success?, error
    output
  end
end
