# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/release_publish_fixture'

class ReleasePublishResumeTest < Minitest::Test
  include ReleasePublishFixture

  def test_a_published_gem_without_a_release_only_creates_the_release
    push_annotated_tag(@commit)
    File.write(state('registry'), Digest::SHA256.file(@gem).hexdigest)
    assert_equal %i[create_release], publish
    refute_path_exists state('pushes')
  end

  def test_upload_and_install_use_the_public_registry
    publish
    assert_includes File.read(state('pushes')), "push --host #{ShakaRelease::Registry::HOST} "
    assert_equal 'github.com', release_record.fetch('host')
    assert_includes File.read(state('installs')), "--remote --clear-sources --source #{ShakaRelease::Registry::HOST}"
  end

  def test_a_local_tag_on_another_commit_is_refused_even_in_a_dry_run
    git('-c', 'user.name=T', '-c', 'user.email=t@example.com', 'commit', '--allow-empty', '-qm', 'Other')
    git('tag', 'v1.2.0', 'HEAD')
    git('push', '-q', 'origin', 'HEAD^:refs/heads/main', '-f')
    error = assert_raises(Shaka::Error) { publish(dry_run: true) }
    assert_includes error.message, 'local tag v1.2.0 points at another commit'
    assert_refused 'local tag v1.2.0 points at another commit'
    assert_nil remote_tag
  end

  def test_an_approved_commit_missing_from_the_checkout_is_refused_in_a_dry_run
    other = File.join(@directory, 'other')
    Open3.capture3('git', 'clone', '-q', File.join(@directory, 'origin.git'), other)
    Open3.capture3('git', '-C', other, '-c', 'user.name=T', '-c', 'user.email=t@example.com', 'commit',
                   '--allow-empty', '-qm', 'Elsewhere')
    Open3.capture3('git', '-C', other, 'push', '-q', 'origin', 'HEAD:main')
    @commit = Open3.capture2('git', '-C', other, 'rev-parse', 'HEAD').first.strip
    @approval = write_approval('1.2.0')
    error = assert_raises(Shaka::Error) { publish(dry_run: true) }
    assert_includes error.message, 'not in this checkout'
  end

  def test_a_local_tag_that_is_not_a_commit_is_refused_in_a_dry_run
    blob = git('hash-object', '-w', 'README.md').strip
    git('tag', 'v1.2.0', blob)
    error = assert_raises(Shaka::Error) { publish(dry_run: true) }
    assert_includes error.message, 'does not name a commit'
  end

  def test_the_tag_push_publishes_no_other_local_tags
    git('config', 'push.followTags', 'true')
    git('tag', '-a', 'private-note', '-m', 'Local only')
    publish
    assert_empty git('ls-remote', 'origin', 'refs/tags/private-note')
  end

  def test_a_lightweight_local_tag_is_refused_in_a_dry_run
    git('tag', 'v1.2.0', @commit)
    error = assert_raises(Shaka::Error) { publish(dry_run: true) }
    assert_includes error.message, 'is not annotated'
  end

  def test_the_cli_refuses_an_invalid_approval_without_a_backtrace
    { JSON.generate(JSON.parse(File.read(@approval)).merge('version' => 'not a version')) => 'has an invalid version',
      '[]' => 'must hold a JSON object' }.each do |text, message|
      File.write(@approval, text)
      output, error, status = Open3.capture3(RbConfig.ruby, File.join(__dir__, '../bin/release'), 'publish',
                                             '--approval', @approval, '--dry-run', chdir: @root)
      refute_predicate status, :success?
      assert_equal ['', "Release refused: approval file #{message}\n"], [output, error]
    end
  end

  def test_a_remote_lightweight_tag_is_refused_before_upload
    git('push', '-q', 'origin', "#{@commit}:refs/tags/v1.2.0")
    assert_refused 'remote tag v1.2.0 is not annotated'
    refute_path_exists state('pushes')
  end

  def test_a_tag_pushed_elsewhere_stops_before_the_gem_upload
    elsewhere = File.join(@directory, 'elsewhere.git')
    git('clone', '-q', '--bare', @root, elsewhere)
    git('config', "url.#{elsewhere}.pushInsteadOf", ShakaRelease::Preflight::REMOTE)
    assert_refused 'is not on'
    refute_path_exists state('pushes')
  end

  def test_inherited_git_overrides_do_not_redirect_publication
    other = File.join(@directory, 'other')
    Open3.capture3('git', 'init', '-q', other)
    Open3.capture3('git', '-C', other, 'config', "url.#{File.join(@directory, 'elsewhere.git')}.insteadOf",
                   ShakaRelease::Preflight::REMOTE)
    @env['GIT_DIR'] = File.join(other, '.git')
    publish
    assert_equal @commit, remote_tag
  end

  def test_an_incomplete_or_unready_approval_is_refused
    File.write(@approval, JSON.generate(JSON.parse(File.read(@approval)).except('notes_sha256')))
    assert_refused 'approval file lacks notes_sha256'
    @approval = write_approval('1.2.0')
    File.write(@approval, JSON.generate(JSON.parse(File.read(@approval)).merge('status' => 'refused')))
    assert_refused 'not ready for approval'
  end

  def test_a_malformed_gate_or_commit_is_refused_before_any_push
    { 'behavior_gate' => 'skipped', 'commit' => 'refs/heads/main' }.each do |key, value|
      @approval = write_approval('1.2.0')
      File.write(@approval, JSON.generate(JSON.parse(File.read(@approval)).merge(key => value)))
      assert_refused 'approval file has an invalid'
    end
    assert_nil remote_tag
    refute_path_exists state('pushes')
  end
end
