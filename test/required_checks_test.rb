# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/required_checks'

class RequiredChecksTest < Minitest::Test
  Client = Struct.new(:native, :head, :configured) do
    def required_checks = native
    def checks = head
    def configured_required_checks = configured || []
  end

  PASS = { 'name' => 'checks', 'state' => 'SUCCESS', 'bucket' => 'pass' }.freeze

  def test_the_seam_list_adds_to_native_required_checks
    native = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
    result = Shaka::RequiredChecks.new(Client.new(native, [PASS]), seam_names: ['checks']).call

    assert_equal({ 'source' => 'github+seam', 'checks' => native + [PASS] }, result)
  end

  # A name GitHub already requires, reported or not, gates once.
  def test_a_seam_name_github_also_requires_is_not_repeated
    native = [PASS]
    missing = { 'name' => 'validate', 'state' => 'MISSING', 'bucket' => 'missing' }
    result = Shaka::RequiredChecks.new(Client.new(native, [PASS], %w[checks validate]),
                                       seam_names: %w[checks validate]).call

    assert_equal({ 'source' => 'github', 'checks' => [PASS, missing] }, result)
  end

  def test_an_unreadable_native_set_stays_unreadable_beside_a_seam_list
    result = Shaka::RequiredChecks.new(Client.new(nil, [PASS]), seam_names: ['checks']).call

    assert_equal({ 'source' => 'github', 'checks' => nil }, result)
  end

  def test_seam_list_applies_when_github_enforces_no_checks
    other = { 'name' => 'lint', 'state' => 'FAILURE', 'bucket' => 'fail' }
    result = Shaka::RequiredChecks.new(Client.new([], [other, PASS]), seam_names: ['checks']).call

    assert_equal({ 'source' => 'seam', 'checks' => [PASS] }, result)
  end

  # An unreported native requirement leaves `gh pr checks --required` empty; it must block, not vanish.
  def test_configured_native_requirements_that_have_not_reported_are_missing
    missing = { 'name' => 'validate', 'state' => 'MISSING', 'bucket' => 'missing' }
    result = Shaka::RequiredChecks.new(Client.new([], [PASS], ['validate'])).call

    assert_equal({ 'source' => 'github', 'checks' => [missing] }, result)
    result = Shaka::RequiredChecks.new(Client.new([], [PASS], ['validate']), seam_names: ['checks']).call

    assert_equal({ 'source' => 'github+seam', 'checks' => [missing, PASS] }, result)
  end

  # A renamed job leaves its configured name unreported beside checks that did report.
  def test_configured_requirements_missing_from_a_non_empty_native_report_are_missing
    missing = { 'name' => 'validate', 'state' => 'MISSING', 'bucket' => 'missing' }
    result = Shaka::RequiredChecks.new(Client.new([PASS], [PASS], %w[checks validate])).call

    assert_equal({ 'source' => 'github', 'checks' => [PASS, missing] }, result)
  end

  def test_configured_native_requirements_use_reported_head_results
    %w[SUCCESS FAILURE IN_PROGRESS].zip(%w[pass fail pending]).each do |state, bucket|
      check = PASS.merge('state' => state, 'bucket' => bucket)
      result = Shaka::RequiredChecks.new(Client.new([], [check], ['checks'])).call

      assert_equal({ 'source' => 'github', 'checks' => [check] }, result)
    end
  end

  def test_configured_native_requirements_preserve_duplicate_results_and_missing_checks
    failed = PASS.merge('state' => 'FAILURE', 'bucket' => 'fail')
    unrelated = PASS.merge('name' => 'optional')
    result = Shaka::RequiredChecks.new(Client.new([], [PASS, failed, unrelated], %w[checks validate])).call

    missing = { 'name' => 'validate', 'state' => 'MISSING', 'bucket' => 'missing' }
    assert_equal({ 'source' => 'github', 'checks' => [PASS, failed, missing] }, result)
  end

  def test_a_seam_check_absent_from_the_head_is_reported_missing
    result = Shaka::RequiredChecks.new(Client.new([], [PASS]), seam_names: %w[checks deploy-preview]).call

    missing = { 'name' => 'deploy-preview', 'state' => 'MISSING', 'bucket' => 'missing' }
    assert_equal [PASS, missing], result.fetch('checks')
  end

  def test_without_a_seam_list_the_empty_native_set_stands
    result = Shaka::RequiredChecks.new(Client.new([], [PASS])).call

    assert_equal({ 'source' => 'github', 'checks' => [] }, result)
  end
end
