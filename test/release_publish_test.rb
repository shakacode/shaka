# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/release_publish_fixture'

class ReleasePublishTest < Minitest::Test
  include ReleasePublishFixture

  def test_publishes_the_tag_gem_and_release_from_the_approved_inputs
    assert_equal %i[push_tag push_gem create_release], publish
    assert_equal @commit, remote_tag
    assert_equal Digest::SHA256.file(@gem).hexdigest, File.read(state('registry'))
    assert_equal "Fixes things.\n", release_record.fetch('body')
    refute_includes release_record.fetch('args'), '--prerelease'
  end

  def test_a_rerun_after_publication_only_checks_the_install
    publish
    assert_empty publish
    assert_equal 1, File.readlines(state('pushes')).size
    assert_equal 2, File.readlines(state('installs')).size
  end

  def test_resumes_after_the_tag_even_when_main_moved
    publish_with_failure('push_fails', 'gem push failed')
    assert_equal @commit, remote_tag
    refute_path_exists state('release')
    advance_main
    assert_equal %i[push_gem create_release], publish
  end

  def test_install_failure_says_to_rerun_and_the_rerun_finishes
    publish_with_failure('install_fails', 'rerun publish in a few minutes')
    assert_empty publish
  end

  def test_dry_run_reports_steps_without_changing_anything
    output = StringIO.new
    assert_equal %i[push_tag push_gem create_release], publish(dry_run: true, out: output)
    assert_includes output.string, 'To do: push the tag, push the gem, create the GitHub release'
    assert_nil remote_tag
    assert_empty Dir.children(@state)
  end

  def test_refuses_changed_inputs_or_a_moved_main
    File.write(@gem, 'other bytes')
    assert_refused 'gem file differs'
    @approval = write_approval('1.2.0')
    advance_main
    assert_refused 'remote main moved'
    assert_empty Dir.children(@state)
  end

  def test_refuses_a_tag_or_gem_that_differs_from_the_approval
    git('-c', 'user.name=T', '-c', 'user.email=t@example.com', 'commit', '--allow-empty', '-qm', 'Other')
    push_annotated_tag
    assert_refused 'points at'
    git('push', '-q', 'origin', ':refs/tags/v1.2.0')
    File.write(state('registry'), 'f' * 64)
    assert_refused 'RubyGems has a different shaka 1.2.0'
    assert_equal ['registry'], Dir.children(@state)
  end

  def test_a_skipped_gate_is_stated_in_a_prerelease
    @approval = write_approval('1.3.0.rc.1', gate: { 'status' => 'skipped' })
    publish
    assert_includes release_record.fetch('args'), '--prerelease'
    assert_equal "Fixes things.\n\n#{ShakaRelease::Approval::SKIPPED_GATE}\n", release_record.fetch('body')
  end

  private

  def publish_with_failure(flag, message)
    File.write(state(flag), '')
    assert_refused message
    File.unlink(state(flag))
  end
end
