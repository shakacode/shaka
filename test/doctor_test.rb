# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/doctor'
require 'fileutils'

class DoctorTest < Minitest::Test
  AUTHENTICATED = "github.com\n  Logged in to github.com account octocat\n"
  WRITABLE = '{"nameWithOwner":"owner/repo","viewerPermission":"WRITE"}'

  def test_a_ready_environment_reports_healthy_and_does_not_block
    report, blocked = doctor
    assert_includes report, 'HEALTHY'
    refute_includes report, 'FAILED'
    refute_includes report, 'DEGRADED'
    refute blocked
  end

  def test_an_unset_alias_degrades_the_report_without_blocking
    report, blocked = doctor(environment: {})
    assert_includes report, 'DEGRADED'
    assert_includes report, 'UNKNOWN'
    refute blocked
  end

  # The alias is published on public pull requests, so doctor must never point at the machine's name.
  def test_alias_guidance_never_offers_a_host_name
    host = 'developer-laptop-m5-max'
    report, = doctor(environment: { 'HOST' => host, 'HOSTNAME' => host })
    assert_includes report, 'DEGRADED'
    refute_includes report, host
  end

  # A value the publication renderer would reject blocks now instead of failing mid-publication.
  def test_an_unpublishable_alias_blocks
    report, blocked = doctor(environment: { 'SHAKA_MACHINE_ALIAS' => 'customer machine' })
    assert_includes report, 'FAILED'
    assert blocked
    refute_includes report, 'customer machine'
  end

  def test_unauthenticated_github_blocks
    report, blocked = doctor(responses: { auth: ['', 'not logged in', false] })
    assert_includes report, 'FAILED'
    assert blocked
  end

  def test_a_missing_github_cli_blocks
    report, blocked = doctor(runner: ->(*) { raise Errno::ENOENT, 'gh' })
    assert_includes report, 'FAILED'
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

  def test_a_checkout_without_github_access_blocks
    reader = ['{"nameWithOwner":"owner/repo","viewerPermission":"READ"}', '', true]
    report, blocked = doctor(responses: { view: reader })
    assert_includes report, 'FAILED'
    assert blocked
  end

  # Somewhere with no GitHub remote is a valid place to run doctor, not a failure.
  def test_a_checkout_without_a_remote_is_skipped_rather_than_failed
    report, blocked = doctor(responses: { view: ['', 'none of the git remotes point to a known host', false] })
    assert_includes report, 'SKIPPED'
    refute blocked
  end

  def test_an_unreadable_usage_source_degrades_without_blocking
    report, blocked = doctor(usage_files: [])
    assert_includes report, 'DEGRADED'
    refute blocked
  end

  # One pass: a blocking failure must not hide the checks after it.
  def test_every_check_is_reported_even_when_one_fails
    ready, = doctor
    broken, = doctor(environment: {}, responses: { auth: ['', 'not logged in', false] })
    assert_equal check_names(ready), check_names(broken)
    assert_operator check_names(broken).length, :>=, 4
  end

  def test_the_worst_status_is_reported_first
    report, = doctor(environment: {}, responses: { auth: ['', 'not logged in', false] })
    statuses = report.scan(/^\[(\w+)\]/).flatten
    assert_equal statuses.sort_by { |status| -Shaka::Doctor::SEVERITY.fetch(status.downcase) }, statuses
  end

  private

  def check_names(report) = report.scan(/^\[\w+\] ([^\n]+?) —/).flatten.sort

  def doctor(root: File.expand_path('..', __dir__), environment: { 'SHAKA_MACHINE_ALIAS' => 'm5' },
             responses: {}, runner: nil, usage_files: ['/transcript.jsonl'])
    runner ||= stub_runner(responses)
    subject = Shaka::Doctor.new(root: root, environment: environment, runner: runner,
                                usage_source: ->(_host) { usage_files })
    [subject.report, subject.blocked?]
  end

  def stub_runner(responses)
    lambda do |argv|
      key = argv.include?('auth') ? :auth : :view
      responses.fetch(key, key == :auth ? [AUTHENTICATED, '', true] : [WRITABLE, '', true])
    end
  end
end
