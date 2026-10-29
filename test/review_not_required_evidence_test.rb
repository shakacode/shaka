# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/publication/settings'

# https://github.com/shakacode/shaka/issues/949: merge skips review evidence when the trusted
# review.required is none, so a description publishes bound validation alone in that repository.
class ReviewNotRequiredEvidenceTest < Minitest::Test
  include EvidenceFixture

  def test_validation_alone_is_ready_when_review_is_not_required
    with_checkout(not_required) do |root, ref|
      with_validation(run_check(root, ref, command: 'validate')) do |validation|
        verdict = verify(root, ref, validation:)
        assert_equal 'ready', verdict.fetch('status')
        assert_empty verdict.fetch('missing')
        refute verdict.fetch('review_required')
      end
    end
  end

  def test_a_supplied_review_must_still_bind_when_review_is_not_required
    with_checkout(not_required) do |root, ref|
      review = review_check(root, ref)
      head = commit_change(root)
      with_results(validation: run_check(root, head, command: 'validate'), review:) do |paths|
        verdict = verify(root, head, **paths)
        assert_equal 'not_ready', verdict.fetch('status')
        assert_equal 'superseded', verdict.dig('checks', 'review', 0, 'status')
      end
    end
  end

  def test_a_missing_review_is_still_refused_when_review_is_required
    %w[meaningful_changes always].each do |required|
      with_checkout('review' => review_policy('required' => required)) do |root, ref|
        with_validation(run_check(root, ref, command: 'validate')) do |validation|
          verdict = verify(root, ref, validation:)
          assert_equal 'not_ready', verdict.fetch('status'), required
          assert_equal ['review'], verdict.fetch('missing'), required
          assert verdict.fetch('review_required'), required
        end
      end
    end
  end

  # The fixture configures two reviewers; none ran, and none were required, so nothing falls short.
  def test_the_description_says_the_repository_does_not_require_review
    with_checkout(not_required) do |root, ref|
      with_validation(run_check(root, ref, command: 'validate')) do |validation|
        settings = prepare(root, ref, validation)
        assert_nil settings.reviewer_shortfall
        assert_includes settings.detail.fetch('body'), 'This repository’s settings do not require review.'
        assert_includes Shaka::VerificationGates.render(settings.verdict),
                        "`validate` passed (exit 0); #{Shaka::VerificationGates::NOT_REQUIRED} at `#{ref[0, 7]}`."
      end
    end
  end

  private

  def not_required
    { 'review' => review_policy('required' => 'none').except('ci_review_jobs') }
  end

  def commit_change(root)
    File.write(File.join(root, 'later.txt'), "changed after review\n")
    git(root, 'add', '-A')
    commit(root)
    git(root, 'rev-parse', 'HEAD')
  end

  def prepare(root, ref, validation)
    pull = { 'changed_files' => 0, 'head' => { 'sha' => ref }, 'base' => { 'sha' => ref } }
    Shaka::PublicationSettings.prepare(root:, ref:, pull:, options: { root:, validation: [validation] },
                                       github: empty_diff)
  end

  def empty_diff
    Object.new.tap do |github|
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      def github.api_list(_path) = []
    end
  end

  def with_validation(result)
    Tempfile.create(['shaka-validation-', '.json']) do |file|
      file.write(JSON.generate(result))
      file.flush
      yield file.path
    end
  end
end
