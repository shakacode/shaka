# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'local_review_batch_test'

# The reviews of one commit are recorded in one triage, only after every one of them finishes.
class LocalReviewTriageTest < Minitest::Test
  include LocalReviewLedgerSteps

  # Break caught: two reviewers' reports of one problem were triaged twice.
  def test_one_triage_records_every_reviewer_of_a_commit
    append(EARLIER, 'openai/codex', findings: 1)
    append(EARLIER, 'anthropic/claude', findings: 1)

    assert_includes assert_raises(Shaka::Error) { record([NIT]) }.message, 'must name the reviewers'
    assert_equal [1, 2], record([NIT.merge('reviewers' => %w[openai/codex anthropic/claude])])
    assert_equal([[NIT], [NIT]], ledger.rounds.map { |round| round['findings'] })
  end

  # Break caught: a batch was triaged while one of its reviewers was still reading the commit.
  def test_recording_waits_for_every_running_review
    append(EARLIER, 'openai/codex', findings: 0)
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')

    assert_includes assert_raises(Shaka::Error) { record([]) }.message, 'Wait for anthropic/claude'
    run.finish!
    assert_equal [1], record([])
  end

  # Break caught: a review killed before it cleared its mark blocked the batch forever.
  def test_a_review_whose_process_exited_does_not_block_recording
    append(EARLIER, 'openai/codex', findings: 0)
    start_in_another_process(EARLIER, 'anthropic/claude')

    assert_equal [1], record([])
    refute JSON.parse(File.read(@path)).key?('running')
    assert_empty Dir.glob("#{@path}.running-*")
  end

  # Break caught: a refused second run of one reviewer cleared the live run's mark.
  def test_a_second_run_of_one_reviewer_on_a_commit_is_refused_and_leaves_the_mark
    append(EARLIER, 'openai/codex', findings: 0)
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')

    error = assert_raises(Shaka::Error) { ledger.start!(base: BASE, head: EARLIER, reviewer: 'Anthropic/Claude') }
    assert_includes error.message, 'already reviewing'
    assert_includes assert_raises(Shaka::Error) { record([]) }.message, 'Wait for anthropic/claude'
    run.finish!
  end

  # Break caught: a misspelled or empty reviewer list dropped its finding without an error.
  def test_every_finding_names_reviewers_of_the_batch
    append(EARLIER, 'openai/codex', findings: 1)
    append(EARLIER, 'anthropic/claude', findings: 0)

    { ['openai/codx'] => 'names openai/codx', [] => 'must name the reviewers' }.each do |named, message|
      assert_includes assert_raises(Shaka::Error) { record([NIT.merge('reviewers' => named)]) }.message, message
    end
  end

  # Break caught: a new commit's review overtook a reviewer still reading the last commit.
  def test_a_new_commit_waits_for_reviews_of_the_last_one
    append(EARLIER, 'openai/codex', findings: 0)
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')

    error = assert_raises(Shaka::Error) { ledger.start!(base: BASE, head: HEAD, reviewer: 'openai/codex') }
    assert_includes error.message, 'Wait for anthropic/claude to finish reviewing'
    run.finish!
  end

  # Break caught: two problems given one id by different reviewers hid one of them.
  def test_one_id_names_one_problem_across_reviewers
    append(EARLIER, 'openai/codex', findings: 1)
    append(EARLIER, 'anthropic/claude', findings: 1)
    findings = [NIT.merge('reviewers' => ['openai/codex']), NIT.merge('reviewers' => ['anthropic/claude'])]

    assert_includes assert_raises(Shaka::Error) { record(findings) }.message, 'id repeats'
  end

  def test_an_append_clears_its_running_mark
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'openai/codex')
    run.append!(base: BASE, round: round_entry(EARLIER, 'openai/codex', 0))

    refute JSON.parse(File.read(@path)).key?('running')
    assert_empty Dir.glob("#{@path}.running-*")
  end

  # Break caught: a reviewer started after triage, so its findings were triaged apart.
  def test_a_reviewer_cannot_join_a_triaged_commit
    append(EARLIER, 'openai/codex', findings: 0)
    record([])

    error = assert_raises(Shaka::Error) { ledger.check_next!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude') }
    assert_includes error.message, 'already recorded'
  end

  # Break caught: usage that named no reviewer of the batch was dropped without an error.
  def test_usage_must_fit_a_reviewer_of_the_batch
    append(EARLIER, 'openai/codex', findings: 0)
    append(EARLIER, 'anthropic/claude', findings: 0)

    { { tokens: '5' } => 'keyed by reviewer', { usage: { 'openai/codx' => {} } } => 'Usage names openai/codx',
      { usage: { 'openai/codex' => '5' } } => 'map each reviewer' }
      .each do |extra, message|
        assert_includes assert_raises(Shaka::Error) { record([], **extra) }.message, message
      end
  end

  def test_usage_is_recorded_for_each_reviewer
    append(EARLIER, 'openai/codex', findings: 0)
    append(EARLIER, 'anthropic/claude', findings: 0)
    record([], usage: { 'openai/codex' => { 'tokens' => '5,000' } })

    assert_equal(['5,000', nil], ledger.rounds.map { |round| round['tokens'] })
  end

  private

  # Marks a review running from a process that then exits, as a killed review would.
  def start_in_another_process(head, reviewer)
    lib = File.expand_path('../skills/shaka/lib', __dir__)
    script = "require 'shaka/local_review'; Shaka::LocalReviewLedger.new(ARGV[0]).start!(base: ARGV[1], " \
             'head: ARGV[2], reviewer: ARGV[3])'
    assert system(RbConfig.ruby, '-I', lib, '-e', script, @path, BASE, head, reviewer)
  end
end
