# frozen_string_literal: true

require_relative 'merge_test'
require 'shaka/merge_base_failures'

# Under Auto a check the base branch fails too may stay red when the agent names it, and only then.
class MergeAutoBaseFailureTest < Minitest::Test
  include MergeFixtures

  BASE_SHA = 'c' * 40

  # Answers the base-tip reads MergeBaseFailures makes, and the auto-merged label calls.
  module BaseApi
    attr_accessor :base_rows

    def base_reads = (@base_reads ||= [])
    def labels = (@labels ||= [])

    def branch_tip(branch)
      base_reads << [:tip, branch]
      BASE_SHA
    end

    def rest_checks(sha)
      base_reads << [:checks, sha]
      base_rows
    end

    def api(path, method: 'GET', **)
      labels << [method, path]
      {}
    end
  end

  def setup
    super
    @client.extend(BaseApi)
    @client.head_checks = [passing('Validate'), failing('windows')]
    # GitHub reports UNSTABLE while an optional check fails.
    @client.snapshots = [snapshot.merge('mergeStateStatus' => 'UNSTABLE')]
    @merge.auto = true
  end

  def test_merges_past_a_named_check_the_base_fails_too
    excuse(base_rows: [failing('windows')])

    result = merge

    assert_equal %w[MERGED applied], result.values_at('state', 'auto_merged_label')
    assert_equal({ 'base' => BASE, 'base_sha' => BASE_SHA, 'checks' => ['windows'] }, result['base_failures_excused'])
    # UNSTABLE no longer shows a new failure, so the checks are read again before submission.
    assert_equal [[:tip, BASE], [:checks, BASE_SHA]] * 2, @client.base_reads
  end

  # The trusted all wait refuses UNSTABLE to wait for CI review jobs; Auto has already required them to pass.
  def test_merges_past_a_base_failure_when_the_trusted_wait_is_all
    @merge = Shaka::Merge.new(@client, seam_wait: 'all')
    @merge.auto = true
    excuse(base_rows: [failing('windows')])

    assert_equal 'MERGED', merge.fetch('state')
  end

  # UNSTABLE hides a check that fails while the reviews are read, so the second read must catch it.
  def test_the_second_read_refuses_a_check_that_failed_meanwhile
    @client.head_checks = [[passing('Validate'), failing('windows')],
                           [passing('Validate'), failing('windows'), failing('lint')]]
    excuse(base_rows: [failing('windows')])

    assert_blocked(/not passing: lint \(FAILURE\)/)
  end

  def test_refuses_a_check_the_base_does_not_fail
    [[[passing('windows')], 'pass'], [[], 'missing'], [[failing('windows'), passing('windows')], 'mixed']]
      .each do |rows, bucket|
        excuse(base_rows: rows)

        assert_blocked(/windows does not fail on main at #{BASE_SHA} \(#{bucket}\)/)
        assert_empty @client.labels
      end
  end

  # GitHub blocks a failing required check, so Shaka will not call it excused.
  def test_refuses_a_required_check
    excuse(base_rows: [failing('windows')])
    @client.checks = [failing('windows')]

    assert_blocked(/windows is a required check/)
  end

  def test_refuses_a_name_that_fails_nothing_on_the_head
    excuse(base_rows: [failing('lint')], names: ['lint'])

    assert_blocked(/--base-failure lint names no failing check on the head/)
  end

  def test_an_unnamed_failing_check_still_blocks
    excuse(base_rows: [failing('windows')])
    @client.head_checks << failing('lint')

    assert_blocked(/not passing: lint \(FAILURE\)/)
  end

  # Without a name the base is never read and Auto keeps waiting for CLEAN.
  def test_without_names_auto_still_refuses_unstable
    assert_blocked(/not CLEAN: "UNSTABLE"/)
    assert_empty @client.base_reads
  end

  private

  def excuse(base_rows:, names: ['windows'])
    @client.base_rows = base_rows
    @merge.base_failures = Shaka::MergeBaseFailures.new(@client, names)
  end

  def passing(name) = { 'name' => name, 'state' => 'SUCCESS', 'bucket' => 'pass' }

  def failing(name) = { 'name' => name, 'state' => 'FAILURE', 'bucket' => 'fail' }

  def merge = @merge.call(head: HEAD, base: BASE, walkthrough: 17)
end
