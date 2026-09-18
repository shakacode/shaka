# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require 'fileutils'

# Doctor must never report a machine ready to publish on access it did not establish.
class DoctorAccessTest < Minitest::Test
  include DoctorHelper

  def test_a_missing_github_cli_blocks
    report, blocked = doctor(runner: ->(*) { raise Errno::ENOENT, 'gh' })
    assert_includes report, 'FAILED'
    assert blocked
  end

  # Authentication and permission are one question about the repository that matters,
  # so a stale credential on an unrelated GitHub host cannot block a usable setup.
  def test_unauthenticated_github_blocks_through_repository_access
    report, blocked = doctor(responses: { view: ['', 'gh auth login required', false] })
    assert_includes report, 'FAILED'
    assert blocked
  end

  def test_a_checkout_without_github_access_blocks
    reader = ['{"nameWithOwner":"owner/repo","viewerPermission":"READ"}', '', true]
    report, blocked = doctor(responses: { view: reader })
    assert_includes report, 'FAILED'
    assert blocked
  end

  # Doctor must never exit zero on write access it did not establish, whatever the reason.
  def test_an_unresolved_repository_blocks_rather_than_passing_quietly
    ['none of the git remotes point to a known host', 'HTTP 404', 'dial tcp: lookup failed'].each do |reason|
      report, blocked = doctor(responses: { view: ['', reason, false] })
      assert_includes report, 'FAILED', reason
      assert blocked, reason
    end
  end

  # A well-formed object is not a repository: healthy has to name what it verified.
  def test_an_object_missing_the_repository_or_permission_blocks
    incomplete = ['{"viewerPermission":"WRITE"}', '{"nameWithOwner":"owner/repo"}',
                  '{"nameWithOwner":7,"viewerPermission":"WRITE"}',
                  '{"nameWithOwner":"","viewerPermission":"WRITE"}']
    incomplete.each do |body|
      report, blocked = doctor(responses: { view: [body, '', true] })
      assert_includes report, 'FAILED', body
      assert blocked, body
    end
  end

  def test_json_of_the_wrong_shape_is_a_check_result_not_a_crash
    ['null', '[]', '"text"'].each do |body|
      report, blocked = doctor(responses: { view: [body, '', true] })
      assert_includes report, 'FAILED', body
      assert blocked, body
    end
  end

  # A gh that cannot even launch must answer its own check, not abort the report.
  def test_an_unlaunchable_github_cli_still_reports_every_check
    report, blocked = doctor(runner: ->(*) { raise Errno::EACCES, 'gh' })
    assert_includes report, 'FAILED'
    assert_includes report, 'Machine alias'
    assert_includes report, 'Usage source'
    assert blocked
  end

  # The summary a user reads should name the missing contract, not leak a file-open error.
  def test_a_missing_repository_seam_blocks_and_names_the_contract
    Dir.mktmpdir do |dir|
      report, blocked = doctor(root: dir)
      assert_includes report, 'FAILED'
      assert_includes report, '.agents/agent-workflow.yml'
      refute_includes report, 'rb_sysopen'
      assert blocked
    end
  end

  def test_an_unreadable_seam_blocks_with_its_validation_error
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, '.agents'))
      File.write(File.join(dir, '.agents', 'agent-workflow.yml'), "version: 99\n")
      report, blocked = doctor(root: dir)
      assert_includes report, 'FAILED'
      assert blocked
    end
  end
end
