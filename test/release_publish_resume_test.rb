# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/release_publish_fixture'

class ReleasePublishResumeTest < Minitest::Test
  include ReleasePublishFixture

  def test_a_published_gem_without_a_release_only_creates_the_release
    git('push', '-q', ShakaRelease::Preflight::REMOTE, "#{@commit}:refs/tags/v1.2.0")
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

  def test_a_draft_or_unreadable_release_is_refused_before_publishing
    File.write(state('release'), '{}')
    File.write(state('draft'), '')
    assert_refused 'is a draft'
    File.write(state('gh_fails'), '')
    assert_refused 'Cannot read the GitHub release'
    assert_nil remote_tag
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
end
