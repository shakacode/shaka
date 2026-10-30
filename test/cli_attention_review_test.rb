# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# The merge label through the real command, trusted settings, and a fake gh that records label writes.
class CliAttentionReviewTest < Minitest::Test
  include CliMergeFixture

  FAKE = <<~'RUBY_SCRIPT'
    #!/usr/bin/env ruby
    require 'json'
    path = ARGV[1].to_s
    pull = { 'number' => 1, 'headRefOid' => 'a' * 40, 'baseRefName' => 'main', 'state' => 'OPEN' }
    if ARGV[0, 2] == %w[api graphql]
      puts JSON.generate('data' => { 'repository' => { 'pullRequest' => pull } })
    elsif path == 'user'
      puts JSON.generate('login' => 'shaka-agent')
    elsif path.include?('/issues/1/comments')
      puts ENV.fetch('PR_COMMENTS', '[]')
    elsif path.include?('/issues/1/labels') && ARGV.include?('POST')
      File.write(ENV.fetch('LABEL_FILE'), 'labeled')
      puts '[]'
    elsif path.include?('/issues/1/labels')
      puts '[]'
    elsif path.include?('/labels/')
      puts JSON.generate('name' => 'awaiting-merge-approval')
    else
      warn "unexpected gh #{ARGV.join(' ')}"
      exit 2
    end
  RUBY_SCRIPT

  CLEAN_OUTCOME = 'No open findings; closed and optional findings are in history.'

  def with_policy(required)
    review = review_policy('required' => required)
    review = review.except('ci_review_jobs') if required == 'none'
    with_repository('merge' => merge_policy, 'review' => review, 'checkpoint' => { 'enabled' => false }) do |root|
      commit_repository(root)
      FileUtils.mkdir_p(File.join(root, 'fake-bin'))
      File.write(fake = File.join(root, 'fake-bin', 'gh'), FAKE)
      File.chmod(0o755, fake)
      yield root, Open3.capture3('git', '-C', root, 'rev-parse', 'HEAD').first.strip
    end
  end

  def label(root, ref, *extra, comments: [])
    @label_file = File.join(root, 'label-written')
    run_command('attention', 'owner/repo', '1', '--state', 'merge', '--root', root, '--ref', ref, *extra,
                root:, env: { 'PR_COMMENTS' => JSON.generate(comments), 'LABEL_FILE' => @label_file })
  end

  def review_comment(outcome)
    { 'user' => { 'login' => 'shaka-agent' }, 'html_url' => 'https://example.test/c/1',
      'body' => "# Local Adversarial Review\n\n**Outcome:** #{outcome}\n\n" \
                "REVIEWED #{HEAD} BY openai/codex EFFORT high FINDINGS 3\n" }
  end

  def test_no_published_review_leaves_the_label_off
    with_policy('meaningful_changes') do |root, ref|
      _output, error, status = label(root, ref)

      refute_predicate status, :success?
      assert_includes error, 'No local-review attestation'
      refute_path_exists @label_file
    end
  end

  def test_open_findings_leave_the_label_off_even_with_a_stated_reason
    with_policy('meaningful_changes') do |root, ref|
      _output, error, status = label(root, ref, '--review-waiver', 'Ship it.',
                                     comments: [review_comment('3 findings need attention.')])

      refute_predicate status, :success?
      assert_includes error, '3 findings'
      refute_path_exists @label_file
    end
  end

  def test_a_clean_review_applies_the_label
    with_policy('meaningful_changes') do |root, ref|
      output, _error, status = label(root, ref,
                                     comments: [review_comment(CLEAN_OUTCOME)])

      assert_predicate status, :success?, output
      assert_equal 'current_head', JSON.parse(output).dig('review', 'basis')
      assert_path_exists @label_file
    end
  end

  def test_a_stated_reason_applies_the_label_when_no_review_ran
    with_policy('meaningful_changes') do |root, ref|
      output, _error, status = label(root, ref, '--review-waiver', 'Docs typo.')

      assert_predicate status, :success?, output
      assert_equal({ 'basis' => 'waived', 'reason' => 'Docs typo.' }, JSON.parse(output)['review'])
      assert_path_exists @label_file
    end
  end

  def test_a_repository_that_requires_no_review_applies_the_label
    with_policy('none') do |root, ref|
      output, _error, status = label(root, ref)

      assert_predicate status, :success?, output
      assert_equal 'not_required', JSON.parse(output).dig('review', 'basis')
      assert_path_exists @label_file
    end
  end

  def test_the_waiver_flag_does_not_apply_to_other_label_states
    _output, error, status = Open3.capture3(*COMMAND, 'attention', 'owner/repo', '1', '--state', 'none',
                                            '--review-waiver', 'Docs typo.')

    refute_predicate status, :success?
    assert_includes error, '--review-waiver is only for merge and attention --state merge'
  end
end
