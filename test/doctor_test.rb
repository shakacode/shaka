# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'

class DoctorTest < Minitest::Test
  include DoctorHelper

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

  # Publication accepts a host name, so doctor is the only thing standing between the
  # machine's own name and every public pull request it would appear in.
  def test_an_alias_set_to_the_machine_name_is_flagged_without_republishing_it
    name = 'developer-laptop-m5-max'
    report, blocked = doctor(environment: { 'SHAKA_MACHINE_ALIAS' => name, 'HOSTNAME' => name })
    assert_includes report, 'DEGRADED'
    refute_includes report, name
    refute blocked
  end

  def test_an_alias_matching_the_host_name_in_another_case_is_still_flagged
    report, = doctor(environment: { 'SHAKA_MACHINE_ALIAS' => 'Build-Host', 'HOST' => 'build-host' })
    assert_includes report, 'DEGRADED'
  end

  def test_a_deliberate_alias_is_healthy_even_when_a_host_name_is_present
    report, blocked = doctor(environment: { 'SHAKA_MACHINE_ALIAS' => 'm5', 'HOST' => 'build-host' })
    refute_includes report, 'DEGRADED'
    refute blocked
  end

  def test_a_missing_usage_source_degrades_without_blocking
    report, blocked = doctor(usage_files: [])
    assert_includes report, 'DEGRADED'
    refute blocked
  end

  # discover only locates sources, so a located-but-unreadable transcript is not healthy.
  def test_a_located_but_unreadable_usage_source_degrades
    report, blocked = doctor(usage_files: ['/definitely/missing/transcript.jsonl'])
    assert_includes report, 'DEGRADED'
    refute blocked
  end

  # One pass: a blocking failure must not hide the checks after it.
  def test_every_check_is_reported_even_when_one_fails
    ready, = doctor
    broken, = doctor(environment: {}, responses: { view: ['', 'gh auth login required', false] })
    assert_equal check_names(ready), check_names(broken)
    assert_equal 5, check_names(broken).length
  end

  def test_the_worst_status_is_reported_first
    report, = doctor(environment: {}, responses: { view: ['', 'gh auth login required', false] })
    statuses = report.scan(/^\[(\w+)\]/).flatten
    assert_equal statuses.sort_by { |status| -Shaka::Doctor::SEVERITY.fetch(status.downcase) }, statuses
  end
end
