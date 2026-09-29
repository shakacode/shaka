# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'local_review_comment_test'
require 'tmpdir'
require 'shaka/local_review'

# Several reviewers read one commit before its findings are recorded and fixed together.
class LocalReviewBatchLedgerTest < Minitest::Test
  include LocalReviewCommentFixture

  BASE = 'd' * 40
  FIX = 'e' * 40

  def setup
    @directory = Dir.mktmpdir('shaka-batch')
    @path = File.join(@directory, 'ledger.json')
  end

  def teardown
    super
    FileUtils.rm_rf(@directory)
  end

  def test_another_reviewer_joins_the_last_commit_before_findings_are_recorded
    append(EARLIER, 'openai/codex', findings: 1)
    ledger.check_next!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')

    error = assert_raises(Shaka::Error) { ledger.check_next!(base: BASE, head: EARLIER, reviewer: 'OpenAI/Codex') }
    assert_includes error.message, 'Round 1 already reviewed'
  end

  # Break caught: a new head started while one reviewer's findings were still unrecorded.
  def test_a_new_head_waits_for_every_reviewer_of_the_last_commit
    append(EARLIER, 'openai/codex', findings: 0)
    append(EARLIER, 'anthropic/claude', findings: 1)

    error = assert_raises(Shaka::Error) { ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex') }
    assert_includes error.message, 'Record round 2'
    record('anthropic/claude', [NIT])
    ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex')
  end

  def test_recording_one_of_several_reviewers_needs_its_identity
    append(EARLIER, 'openai/codex', findings: 1)
    append(EARLIER, 'anthropic/claude', findings: 1)

    assert_includes assert_raises(Shaka::Error) { record(nil, [NIT]) }.message, 'pass --reviewer'
    assert_includes assert_raises(Shaka::Error) { record('xai/grok', [NIT]) }.message, 'No round by xai/grok'
    record('openai/codex', [NIT])
    assert_equal([[NIT], nil], ledger.rounds.map { |round| round['findings'] })
  end

  # Break caught: the next head skipped a fix that only the second reviewer's round recorded.
  def test_the_next_head_must_hold_fixes_from_every_reviewer_of_the_last_commit
    append(EARLIER, 'openai/codex', findings: 0)
    append(EARLIER, 'anthropic/claude', findings: 1)
    record('anthropic/claude', [NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => FIX)])

    assert_equal [FIX], ledger.last_round_fixes
  end

  # Break caught: the second reviewer of a commit anchored on the first reviewer's findings.
  def test_reviewers_of_one_commit_see_only_earlier_commits_findings
    append(EARLIER, 'openai/codex', findings: 1)
    record(nil, [NIT])
    append(HEAD, 'openai/codex', findings: 1)
    record(nil, [NIT.merge('id' => 'F2')])

    assert_equal EARLIER, ledger.previous_head(HEAD)
    assert_equal ['F1'], ledger.prior_findings(HEAD).map(&:id)
  end

  # Break caught: a reviewer that finished after a newer commit was appended split its batch apart.
  def test_a_late_round_cannot_rejoin_an_older_commit
    append(EARLIER, 'openai/codex', findings: 0)
    append(HEAD, 'openai/codex', findings: 0)

    error = assert_raises(Shaka::Error) { append(EARLIER, 'anthropic/claude', findings: 0) }
    assert_includes error.message, 'Round 1 already reviewed'
    assert_includes assert_raises(Shaka::Error) { append(HEAD, 'openai/codex', findings: 0) }.message, 'Round 2'
  end

  # Break caught: two reviewers started on one empty ledger with different bases mixed their diffs.
  def test_an_append_rechecks_the_base
    append(EARLIER, 'openai/codex', findings: 0)
    round = round_entry(EARLIER, 'anthropic/claude', 0)

    error = assert_raises(Shaka::Error) { ledger.append!(base: 'f' * 40, round:) }
    assert_includes error.message, 'use a new ledger'
  end

  # Break caught: two reviewers finishing together each wrote the ledger they had read, losing a round.
  def test_concurrent_appends_keep_every_round
    readers = [ledger, ledger]
    readers.each(&:rounds)
    readers.zip(%w[openai/codex anthropic/claude]).map do |reader, reviewer|
      Thread.new { reader.append!(base: BASE, round: round_entry(EARLIER, reviewer, 0)) }
    end.each(&:join)

    assert_equal %w[openai/codex anthropic/claude].sort, ledger.rounds.map { |round| round['reviewer'] }.sort
  end

  private

  def ledger = Shaka::LocalReviewLedger.new(@path)

  def append(head, reviewer, findings:)
    ledger.append!(base: BASE, round: round_entry(head, reviewer, findings))
  end

  def round_entry(head, reviewer, findings)
    { 'head' => head, 'reviewer' => reviewer, 'report' => report(head, reviewer:, findings:) }
  end

  def record(reviewer, findings) = ledger.record!({ 'findings' => findings }, reviewer:)
end

# A published comment lists every reviewer of a commit together.
class LocalReviewBatchCommentTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_renders_two_reviewers_of_one_commit_and_closes_with_the_last
    body = render('rounds' => [clean('openai/codex'), clean('anthropic/claude')])

    assert_includes body, '**Outcome:** the loop ended clean: rounds 1–2 found nothing.'
    assert body.end_with?("REVIEWED #{HEAD} BY anthropic/claude EFFORT UNKNOWN FINDINGS 0\n")
  end

  # Break caught: a clean last reviewer hid its sibling's documented findings.
  def test_outcome_counts_every_reviewer_of_the_last_commit
    body = render('rounds' => [round, clean('anthropic/claude')])

    assert_includes body, "Rounds 1–2's findings are documented nits or risks (1 nit)."
  end

  # Break caught: a finding both reviewers of one commit reported read as returning after its fix.
  def test_both_reviewers_of_a_commit_may_report_a_finding_later_fixed
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => HEAD)
    first = round(EARLIER, report: report(EARLIER), findings: [fixed])
    second = round(EARLIER, reviewer: 'anthropic/claude', findings: [fixed],
                            report: report(EARLIER, reviewer: 'anthropic/claude'))

    refute_includes render('rounds' => [first, second, clean('openai/codex')]), 'returned after its fix'
  end

  def test_refuses_one_reviewer_reading_a_commit_twice
    error = assert_raises(Shaka::Error) { render('rounds' => [clean('openai/codex'), clean('OpenAI/Codex')]) }

    assert_includes error.message, 'same reviewer'
  end

  def test_refuses_a_commit_whose_rounds_are_split_apart
    rounds = [clean('openai/codex'), clean('openai/codex', EARLIER), clean('anthropic/claude')]

    assert_includes assert_raises(Shaka::Error) { render('rounds' => rounds) }.message, 'listed together'
  end

  # Break caught: a fix recorded by the first reviewer of the last commit was never reviewed.
  def test_refuses_a_fix_recorded_anywhere_in_the_last_commit
    fixed = round(findings: [NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => EARLIER)])

    error = assert_raises(Shaka::Error) { render('rounds' => [fixed, clean('anthropic/claude')]) }
    assert_includes error.message, 'Round 1 records fixes no later round reviewed'
  end

  private

  def clean(reviewer, head = HEAD)
    round(head, reviewer:, report: report(head, body: "no findings\n", reviewer:, findings: 0), findings: [])
  end
end
