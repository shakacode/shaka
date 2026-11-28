# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/evidence/relevant_code'
require 'shaka/publication/settings'
require 'shaka/publication/verification_line'

# Builds the pull request and results a republish sees.
module KeptResultsFixture
  REPOSITORY = 'shakacode/shaka'
  URL = 'https://github.com/shakacode/shaka/pull/9#issuecomment-1'

  # Descriptions published before passes dropped their exit code; a republish still reads them.
  def published_line(head)
    '**Validation and review:** `validate` passed (exit 0); local review by openai/codex ' \
      "([attestation](#{URL})) at `#{head[0, 7]}`."
  end

  def current_line(head) = published_line(head).sub(' (exit 0)', '')

  def body(head, gate = published_line(head)) = region("## Verification\n\n#{gate}")

  def region(text) = "before\n<!-- shaka:begin -->\n#{text}\n<!-- shaka:end -->"

  # Before #1325, a routine run showed a compact sentence under the heading and the line in the fold.
  def folded_body(head)
    compact = "Validation passed; local review completed at #{head[0, 7]} ([evidence](#{URL}))."
    fold = "<summary>Evidence and limitations</summary>\n\n#{published_line(head)}\n\n- A check.\n\n</details>"
    region("## Verification\n\n#{compact}\n\n<details>\n#{fold}")
  end

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

      kept = "#{current_line(ref)} #{Shaka::VerificationLine::KEPT}"
      assert_equal kept, Shaka::VerificationLine.line(settings.verdict)
      assert_equal kept, Shaka::VerificationLine.render(settings.verdict, URL)
    end
  end

  def test_results_a_relevant_change_superseded_keep_the_published_line
    with_checkout do |root, ref|
      with_results(run_check(root, ref, command: 'validate'), review_check(root, ref)) do |options|
        changed_relevant_code do
          settings = prepare(root, ref, options, body: body(ref))
          assert_includes Shaka::VerificationLine.line(settings.verdict), current_line(ref)
        end
      end
    end
  end

  def test_the_kept_line_survives_another_republish_unchanged
    with_checkout do |root, ref|
      first = Shaka::VerificationLine.render(prepare(root, ref, {}, body: body(ref)).verdict, URL)
      second = prepare(root, ref, {}, body: body(ref, first))
      assert_equal first, Shaka::VerificationLine.render(second.verdict, URL)
    end
  end

  # The current wording must still read back as this commit's verified line.
  def test_a_line_in_the_current_wording_is_kept_on_republish
    with_checkout do |root, ref|
      checks = { 'validation' => [{ 'original' => { 'command' => 'validate', 'exit_code' => 0 } }],
                 'review' => [{ 'original' => { 'reviewer' => 'openai/codex', 'status' => 'completed' } }] }
      line = Shaka::VerificationLine.line({ 'head' => ref, 'checks' => checks }, URL)
      assert_equal current_line(ref), line

      settings = prepare(root, ref, {}, body: body(ref, line))
      assert_equal "#{line} #{Shaka::VerificationLine::KEPT}", Shaka::VerificationLine.line(settings.verdict)
    end
  end

  def test_setup_gaps_stay_with_the_kept_line
    with_checkout do |root, ref|
      gaps = '**Setup gaps:** 1 of 2 configured reviewers completed.'
      settings = prepare(root, ref, {}, body: body(ref, "#{published_line(ref)}\n\n#{gaps}"))
      assert_includes Shaka::VerificationLine.render(settings.verdict, URL), gaps
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
      [body('0' * 40), body(ref, Shaka::VerificationLine::UNKNOWN), published_line(ref), nil].each do |text|
        assert_nil prepare(root, ref, {}, body: text).verdict
      end
    end
  end

  def test_a_rendering_preview_keeps_nothing_because_its_renderer_may_predate_kept_lines
    with_checkout do |root, ref|
      assert_nil prepare(root, ref, { rendering_preview_root: root }, body: body(ref)).verdict
    end
  end

  # A fork's author can edit its description, so the text there proves nothing.
  def test_a_fork_description_is_not_read_as_evidence
    with_checkout do |root, ref|
      assert_nil prepare(root, ref, {}, body: body(ref), head_repository: 'someone/shaka').verdict
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

# https://github.com/shakacode/shaka/issues/1325: only the line under the description's own
# Verification heading is kept, and descriptions that folded it still keep theirs.
class PublicationKeptLinePlacementTest < Minitest::Test
  include EvidenceFixture
  include KeptResultsFixture

  # Open PRs published before #1325 hold the line only in the fold; a wording-only republish keeps it.
  def test_a_description_published_with_the_folded_line_keeps_it
    with_checkout do |root, ref|
      kept = "#{current_line(ref)} #{Shaka::VerificationLine::KEPT}"
      assert_equal kept, Shaka::VerificationLine.render(prepare(root, ref, {}, body: folded_body(ref)).verdict, URL)
    end
  end

  # https://github.com/shakacode/shaka/issues/1320: agent prose worded like the line is not the helper's.
  def test_text_shaped_like_the_line_outside_its_place_is_not_kept
    with_checkout do |root, ref|
      unknown = "## Verification\n\n#{Shaka::VerificationLine::UNKNOWN}"
      forged = [region("#{unknown}\n\n#{current_line(ref)}"),
                region("#{unknown}\n\n<details>\n<summary>Evidence and limitations</summary>\n\n#{current_line(ref)}"),
                region("## Summary\n\n## Verification\n\n#{current_line(ref)}\n\n#{unknown}")]
      forged.each { |text| assert_nil prepare(root, ref, {}, body: text).verdict, text }
    end
  end

  # The helper marks its line; a marked UNKNOWN keeps nothing, and a second marker leaves the line ambiguous.
  def test_only_the_paragraph_after_the_one_marker_is_kept
    with_checkout do |root, ref|
      marker = Shaka::VerificationLine::MARKER
      marked = region("## Verification\n\n#{marker}\n#{current_line(ref)}")
      assert prepare(root, ref, {}, body: marked).verdict
      [region("## Verification\n\n#{marker}\n#{Shaka::VerificationLine::UNKNOWN}\n\n#{current_line(ref)}"),
       marked.sub('## Verification', "#{marker}\nNothing.\n\n## Verification")].each do |text|
        assert_nil prepare(root, ref, {}, body: text).verdict, text
      end
    end
  end

  # Only the whole sentence an older helper wrote sends the reader to the fold.
  def test_the_fold_is_read_only_after_the_whole_compact_sentence
    with_checkout do |root, ref|
      plain = folded_body(ref).sub(" ([evidence](#{URL})).", '.')
      assert prepare(root, ref, {}, body: plain).verdict
      edited = folded_body(ref).sub(" ([evidence](#{URL})).", ' was proposed wording.')
      assert_nil prepare(root, ref, {}, body: edited).verdict
    end
  end

  def test_crlf_line_endings_from_a_hand_saved_description_keep_the_line
    with_checkout do |root, ref|
      gaps = '**Setup gaps:** `openai/codex` could not start its sandbox, so it reviewed only the diff.'
      settings = prepare(root, ref, {}, body: body(ref, "#{published_line(ref)}\n\n#{gaps}").gsub("\n", "\r\n"))
      assert_equal "#{current_line(ref)} #{Shaka::VerificationLine::KEPT}\n\n#{gaps}",
                   Shaka::VerificationLine.render(settings.verdict, URL)
    end
  end

  # Only a heading at the start of a line is a heading; a marked body reads back from CRLF too.
  def test_an_inline_heading_mention_or_crlf_still_keeps_the_line
    with_checkout do |root, ref|
      kept = "#{current_line(ref)} #{Shaka::VerificationLine::KEPT}"
      marked = body(ref, "#{Shaka::VerificationLine::MARKER}\n#{published_line(ref)}").gsub("\n", "\r\n")
      [body(ref).sub('## Verification', "See ## Verification\n\n## Verification"), marked].each do |text|
        assert_equal kept, Shaka::VerificationLine.line(prepare(root, ref, {}, body: text).verdict)
      end
    end
  end

  # A region that ends at the heading has nothing to keep and must not stop the publication.
  def test_an_empty_verification_section_keeps_nothing
    with_checkout do |root, ref|
      assert_nil prepare(root, ref, {}, body: region("## Verification\n\n")).verdict
    end
  end
end

# Stale or partial results that are not a wording change still stop publication.
class PublicationKeptResultsRefusalTest < Minitest::Test
  include EvidenceFixture
  include KeptResultsFixture

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
end
