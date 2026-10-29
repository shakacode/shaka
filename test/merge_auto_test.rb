# frozen_string_literal: true

require_relative 'merge_test'

# Under Auto every check on the head must pass, not only the required ones, and a confirmed
# merge carries the auto-merged label.
class MergeAutoTest < Minitest::Test
  include MergeFixtures

  # Records label calls; `failing` lists the paths that answer with a GitHub error.
  module LabelApi
    attr_accessor :failing

    def api_calls = (@api_calls ||= [])

    def api(path, method: 'GET', fields: {}, expected: Hash)
      api_calls << [method, path, fields]
      status = (failing || {})[[method, path]]
      raise Shaka::Error.new("HTTP #{status}", http_status: status) if status

      expected == Array ? [] : {}
    end
  end

  LABELS = 'repos/owner/repo/issues/42/labels'

  def setup
    super
    @client.extend(LabelApi)
    @client.head_checks = [passing('Validate'), passing('windows')]
    @merge.auto = true
  end

  def test_merges_and_labels_when_every_check_passed
    result = merge

    assert_equal 'MERGED', result.fetch('state')
    assert_equal 'applied', result.fetch('auto_merged_label')
    assert_includes @client.api_calls, ['POST', LABELS, { labels: ['auto-merged'] }]
  end

  def test_refuses_a_failing_or_pending_check_that_is_not_required
    [{ 'state' => 'FAILURE', 'bucket' => 'fail' }, { 'state' => 'PENDING', 'bucket' => 'pending' }].each do |row|
      @client.head_checks = [passing('Validate'), row.merge('name' => 'windows')]

      assert_blocked(/every check on the head passed; not passing: windows \(#{row['state']}\)/)
      assert_empty @client.api_calls
    end
  end

  def test_skipped_and_neutral_checks_count_as_passing
    @client.head_checks = [passing('Validate'), { 'name' => 'docs', 'state' => 'SKIPPED', 'bucket' => 'skipping' },
                           { 'name' => 'lint', 'state' => 'NEUTRAL', 'bucket' => 'skipping' }]

    assert_equal 'applied', merge.fetch('auto_merged_label')
  end

  def test_refuses_unstable_although_the_seam_waits_for_one_review
    @merge = Shaka::Merge.new(@client, seam_wait: 'one')
    @merge.auto = true
    @client.snapshots = [snapshot.merge('mergeStateStatus' => 'UNSTABLE')]

    assert_blocked(/not CLEAN: "UNSTABLE"/)
  end

  def test_a_label_failure_reports_the_merge_it_cannot_undo
    @client.failing = { ['POST', LABELS] => 403 }

    result = merge

    assert_equal 'MERGED', result.fetch('state')
    assert_match(/\Afailed: HTTP 403/, result.fetch('auto_merged_label'))
  end

  def test_creates_the_repository_label_when_missing
    @client.failing = { ['GET', 'repos/owner/repo/labels/auto-merged'] => 404 }

    assert_equal 'applied', merge.fetch('auto_merged_label')
    assert(@client.api_calls.any? { |method, path, _| method == 'POST' && path == 'repos/owner/repo/labels' })
  end

  # A queue base reports BLOCKED until the queue runs, so Auto enqueues there once every head check passed.
  def test_a_queued_pull_request_is_not_labeled_until_it_merges
    entry = queue_entry
    ready = snapshot.merge('isMergeQueueEnabled' => true, 'mergeStateStatus' => 'BLOCKED')
    @client.snapshots = [ready, ready, ready.merge('isInMergeQueue' => true, 'mergeQueueEntry' => entry)]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => entry } }

    assert_equal 'not_applied_merge_queue', merge.fetch('auto_merged_label')
    assert_empty @client.api_calls
  end

  def test_without_auto_optional_checks_and_labels_are_left_alone
    @merge.auto = false
    @client.head_checks = [{ 'name' => 'windows', 'state' => 'FAILURE', 'bucket' => 'fail' }]
    @client.snapshots = [snapshot.merge('mergeStateStatus' => 'UNSTABLE')]

    refute merge.key?('auto_merged_label')
    assert_empty @client.api_calls
  end

  private

  def passing(name) = { 'name' => name, 'state' => 'SUCCESS', 'bucket' => 'pass' }

  def merge = @merge.call(head: HEAD, base: BASE, walkthrough: 17)
end
