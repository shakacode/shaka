# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/evidence/relevant_code'
require 'shaka/publication/settings'
require 'shaka/publication/verification_gates'

# Builds the pull request and results a republish sees.
module KeptResultsFixture
  REPOSITORY = 'shakacode/shaka'
  URL = 'https://github.com/shakacode/shaka/pull/9#issuecomment-1'

  def published_line(head)
    '**Validation and review:** `validate` passed (exit 0); local review by openai/codex ' \
      "([attestation](#{URL})) at `#{head[0, 7]}`."
  end

  def body(head, gate = published_line(head)) = "before\n<!-- shaka:begin -->\n#{gate}\n<!-- shaka:end -->"

  def prepare(root, ref, options, body:, head_repository: REPOSITORY)
    pull = { 'changed_files' => 0, 'body' => body, 'base' => { 'sha' => ref },
             'head' => { 'sha' => ref, 'repo' => { 'full_name' => head_repository } } }
    Shaka::PublicationSettings.prepare(root:, ref:, pull:, options: options.merge(root:), github: empty_diff)
  end

  def empty_diff
    Object.new.tap do |github|
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      def github.api_list(_path) = []
    end
  end

  def changed_relevant_code
    code = Shaka::Evidence::RelevantCode
    original = code.method(:digest)
    code.define_singleton_method(:digest) { |**| 'changed' }
    yield
  ensure
    code.define_singleton_method(:digest, original)
  end

  def with_results(validation, review)
    Tempfile.create(['validation-', '.json']) do |first|
      Tempfile.create(['review-', '.json']) do |second|
        first.write(JSON.generate(validation))
        second.write(JSON.generate(review))
        first.flush
        second.flush
        yield validation: [first.path], review: [second.path]
      end
    end
  end
end

# PR #998: after full validation, a wording-only rewrite of the description was refused as stale
# when the install had moved, and the PR finally went out showing validation as UNKNOWN.
class PublicationKeptResultsTest < Minitest::Test
  include EvidenceFixture
  include KeptResultsFixture

  def test_a_republish_without_results_keeps_the_line_published_for_this_commit
    with_checkout do |root, ref|
      settings = prepare(root, ref, {}, body: body(ref))

      kept = "#{published_line(ref)} #{Shaka::VerificationGates::KEPT}"
      assert_equal kept, Shaka::VerificationGates.line(settings.verdict)
      assert_equal kept, Shaka::VerificationGates.render(settings.verdict, URL)
    end
  end

  def test_results_a_relevant_change_superseded_keep_the_published_line
    with_checkout do |root, ref|
      with_results(run_check(root, ref, command: 'validate'), review_check(root, ref)) do |options|
        changed_relevant_code do
          settings = prepare(root, ref, options, body: body(ref))
          assert_includes Shaka::VerificationGates.line(settings.verdict), published_line(ref)
        end
      end
    end
  end

  def test_the_kept_line_survives_another_republish_unchanged
    with_checkout do |root, ref|
      first = Shaka::VerificationGates.render(prepare(root, ref, {}, body: body(ref)).verdict, URL)
      second = prepare(root, ref, {}, body: "<!-- shaka:begin -->\n#{first}\n<!-- shaka:end -->")
      assert_equal first, Shaka::VerificationGates.render(second.verdict, URL)
    end
  end

  def test_setup_gaps_stay_with_the_kept_line
    with_checkout do |root, ref|
      gaps = '**Setup gaps:** 1 of 2 configured reviewers completed.'
      settings = prepare(root, ref, {}, body: body(ref, "#{published_line(ref)}\n\n#{gaps}"))
      assert_includes Shaka::VerificationGates.render(settings.verdict, URL), gaps
    end
  end

  def test_current_results_replace_the_published_line
    with_checkout do |root, ref|
      with_results(run_check(root, ref, command: 'validate'), review_check(root, ref)) do |options|
        settings = prepare(root, ref, options, body: body(ref))
        assert_equal 'ready', settings.verdict.fetch('status')
      end
    end
  end

  def test_nothing_is_kept_without_a_verified_line_for_this_commit
    with_checkout do |root, ref|
      [body('0' * 40), body(ref, Shaka::VerificationGates::UNKNOWN), published_line(ref), nil].each do |text|
        assert_nil prepare(root, ref, {}, body: text).verdict
      end
    end
  end

  # A fork's author can edit its description, so the text there proves nothing.
  def test_a_fork_description_is_not_read_as_evidence
    with_checkout do |root, ref|
      assert_nil prepare(root, ref, {}, body: body(ref), head_repository: 'someone/shaka').verdict
    end
  end

  def test_results_that_failed_for_another_reason_still_refuse_publication
    with_checkout do |root, ref|
      review = review_check(root, ref)
      failed = run_check(root, ref, command: 'validate').merge('status' => 'not_completed')
      with_results(failed, review) do |options|
        assert_raises(Shaka::Error) { prepare(root, ref, options, body: body(ref)) }
      end
    end
  end

  # A republish that supplies only some results is not a wording change, so it still needs them all.
  def test_a_missing_required_result_still_refuses_publication
    with_checkout do |root, ref|
      with_results(run_check(root, ref, command: 'validate'), review_check(root, ref)) do |options|
        assert_raises(Shaka::Error) { prepare(root, ref, options.except(:review), body: body(ref)) }
        changed_relevant_code do
          assert_raises(Shaka::Error) { prepare(root, ref, options.except(:review), body: body(ref)) }
        end
      end
    end
  end

  def test_a_supplied_failure_is_not_dropped_for_the_earlier_pass
    with_checkout do |root, ref|
      failed = run_check(root, ref, command: 'validate').merge('exit_code' => 1)
      stale = review_check(root, ref)
      stale.fetch('public_settings')['merge.preference'] = 'ask'
      with_results(failed, stale) do |options|
        assert_raises(Shaka::Error) { prepare(root, ref, options, body: body(ref)) }
      end
    end
  end

  def test_stale_results_without_a_published_line_still_refuse_publication
    with_checkout do |root, ref|
      with_results(run_check(root, ref, command: 'validate'), review_check(root, ref)) do |options|
        changed_relevant_code do
          assert_raises(Shaka::Error) { prepare(root, ref, options, body: nil) }
        end
      end
    end
  end

  def test_the_settings_block_says_the_results_were_kept_rather_than_rechecked
    with_checkout do |root, ref|
      detail = prepare(root, ref, {}, body: body(ref)).detail.fetch('body')
      assert_includes detail, 'not rechecked'
      refute_includes detail, 'match this PR’s current commit'
    end
  end
end
