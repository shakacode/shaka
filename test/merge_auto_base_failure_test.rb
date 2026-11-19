# frozen_string_literal: true

require_relative 'merge_test'
require 'shaka/merge_base_failures'

# Under Auto a check the base branch fails too may stay red when the agent names it, and only then.
class MergeAutoBaseFailureTest < Minitest::Test
  include MergeFixtures

  BASE_SHA = 'c' * 40

  # Answers the base-tip reads MergeBaseFailures makes, and the auto-merged label calls.
  module BaseApi
    attr_accessor :base_rows, :tips

    def base_reads = (@base_reads ||= [])
    def labels = (@labels ||= [])

    def branch_tip(branch)
      base_reads << [:tip, branch]
      tips&.shift || BASE_SHA
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

  # The result names the base commit the last read verified, though the base moved since the first.
  def test_reports_the_base_commit_of_the_last_read
    excuse(base_rows: [failing('windows')])
    @client.tips = ['d' * 40, 'e' * 40]

    assert_equal 'e' * 40, merge.dig('base_failures_excused', 'base_sha')
  end

  # A repository that waits for every CI review keeps CLEAN as its minimum, so Auto hands these back.
  def test_a_trusted_all_wait_still_refuses_unstable
    @merge = Shaka::Merge.new(@client, seam_wait: 'all')
    @merge.auto = true
    excuse(base_rows: [failing('windows')])

    assert_blocked(/not CLEAN: "UNSTABLE"/)
  end

  # UNSTABLE hides a check that fails after the first read, so the read just before submission must
  # catch one that fails as late as the final snapshot.
  def test_the_last_read_refuses_a_check_that_failed_meanwhile
    excuse(base_rows: [failing('windows')])
    checks = @client.head_checks
    reads = 0
    @client.define_singleton_method(:snapshot) do
      reads += 1
      checks << { 'name' => 'lint', 'state' => 'FAILURE', 'bucket' => 'fail' } if reads == 2
      super()
    end

    assert_blocked(/not passing: lint \(FAILURE\)/)
  end

  # A check the settings require stays required although GitHub's own required checks replace that list.
  def test_refuses_a_check_merge_required_checks_names
    @merge = Shaka::Merge.new(@client, seam_required_checks: ['windows'])
    @merge.auto = true
    excuse(base_rows: [failing('windows')])

    assert_blocked(/windows is a required check/)
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

    assert_blocked(/--base-failure lint needs every head check of that name to fail/)
  end

  # Head rows that disagree settle nothing, as base rows that disagree do not.
  def test_refuses_a_name_another_head_row_passes
    excuse(base_rows: [failing('windows')])
    @client.head_checks << passing('windows')

    assert_blocked(/--base-failure windows needs every head check of that name to fail/)
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
