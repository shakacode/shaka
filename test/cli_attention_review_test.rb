# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# The merge label through the real command, trusted settings, and a fake gh that records writes.
module CliAttentionFixture
  include CliMergeFixture

  FAKE = <<~'RUBY_SCRIPT'
    #!/usr/bin/env ruby
    require 'json'
    path = ARGV[1].to_s
    pull = { 'number' => 1, 'headRefOid' => 'a' * 40, 'baseRefName' => 'main', 'state' => 'OPEN' }
    if ARGV[0, 2] == %w[api graphql]
      request = JSON.parse($stdin.read)
      if request.fetch('query').include?('headRefOid') && (change = ENV['PR_CHANGE'])
        reads = "#{ENV.fetch('LABEL_FILE')}.reads"
        count = File.exist?(reads) ? File.read(reads).to_i + 1 : 1
        File.write(reads, count)
        pull['state'] = 'CLOSED' if change == 'reopen' && count <= 2
        pull['baseRefName'] = 'release' if change.start_with?('retarget') && count >= change[-1].to_i
      end
      puts JSON.generate('data' => { 'repository' => { 'pullRequest' => pull } })
    elsif path == 'repos/owner/repo/pulls/1'
      if ARGV.include?('PATCH')
        body = JSON.parse($stdin.read).fetch('body')
        File.write(ENV.fetch('LABEL_FILE') + '.body', body)
      else
        body = ENV.fetch('PR_BODY', '')
      body += "\nConcurrent edit." if File.exist?("#{ENV.fetch('LABEL_FILE')}.changed")
      end
      puts JSON.generate('head' => { 'sha' => pull['headRefOid'] }, 'base' => { 'ref' => 'main' },
                         'state' => 'open', 'body' => body)
    elsif ARGV[0, 2] == %w[pr checks]
      if ENV['EDIT_WHILE_READING_CHECKS'] && ARGV.last.include?('completedAt')
        File.write("#{ENV.fetch('LABEL_FILE')}.changed", '')
      end
      rows = JSON.parse(ENV.fetch('PR_CHECKS', '[]'))
      rows.select! { |row| row['name'] == 'validate' } if ARGV.include?('--required')
      puts JSON.generate(rows)
    elsif path.start_with?('repos/owner/repo/rules/branches/main')
      puts '[]'
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

  def label(root, ref, *extra, comments: [], env: {})
    @label_file = File.join(root, 'label-written')
    run_command('attention', 'owner/repo', '1', '--state', 'merge', '--root', root, '--ref', ref, *extra,
                root:, env: { 'PR_COMMENTS' => JSON.generate(comments), 'LABEL_FILE' => @label_file }.merge(env))
  end

  def review_comment(outcome)
    { 'user' => { 'login' => 'shaka-agent' }, 'html_url' => 'https://example.test/c/1',
      'body' => "<!-- shaka:reply:local-review-loop-abc-def -->\n# Local Adversarial Review\n\n" \
                "<!-- shaka:local-reviewers #{HEAD} openai/codex -->\n\n" \
                "**Reviewed revision:** #{HEAD}\n\n**Outcome:** #{outcome}\n\n" \
                "REVIEWED #{HEAD} BY openai/codex EFFORT high FINDINGS 3\n" }
  end
end

class CliAttentionReviewTest < Minitest::Test
  include CliAttentionFixture

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

class CliAttentionTimingTest < Minitest::Test
  include CliAttentionFixture

  def test_merge_handoff_refreshes_ready_pending_after_ci_finishes
    with_policy('meaningful_changes') do |root, ref|
      output, error, status = label(root, ref, comments: [review_comment(CLEAN_OUTCOME)], env: timing_env('pass'))

      assert_predicate status, :success?, error
      assert_equal 'updated', JSON.parse(output)['timing_refresh']
      body = File.read("#{@label_file}.body")
      assert_includes body, '**Estimated token costs:** $3.31 · ready in 34m'
      assert_includes body, 'CI to ready 8m'
      assert body.start_with?("Human introduction.\n") && body.end_with?("Human footer.\n")
    end
  end

  def test_merge_handoff_waits_for_required_ci
    with_policy('meaningful_changes') do |root, ref|
      _output, error, status = label(root, ref, comments: [review_comment(CLEAN_OUTCOME)], env: timing_env('pending'))

      refute_predicate status, :success?
      assert_includes error, 'Required check is not passing'
      refute_path_exists @label_file
      refute_path_exists "#{@label_file}.body"
    end
  end

  def test_merge_handoff_does_not_overwrite_a_concurrent_description_edit
    with_policy('meaningful_changes') do |root, ref|
      env = timing_env('pass').merge('EDIT_WHILE_READING_CHECKS' => '1')
      output, error, status = label(root, ref, comments: [review_comment(CLEAN_OUTCOME)], env:)

      assert_predicate status, :success?, error
      assert_equal 'changed', JSON.parse(output)['timing_refresh']
      refute_path_exists "#{@label_file}.body"
    end
  end

  def test_merge_handoff_refuses_a_closed_snapshot_even_if_the_pr_reopens
    assert_refused_handoff({ 'PR_CHANGE' => 'reopen' }, 'Pull request is not open.', comments: [])
  end

  def test_merge_handoff_refuses_a_retarget_while_reading_the_gate
    assert_refused_handoff({ 'PR_CHANGE' => 'retarget2' }, 'PR base changed')
  end

  def test_merge_handoff_refuses_a_retarget_before_labeling
    assert_refused_handoff({ 'PR_CHANGE' => 'retarget3' }, 'PR base changed')
  end

  def test_merge_handoff_asks_for_a_fresh_preview_before_labeling
    marker = "<!-- shaka:rendering-preview #{HEAD} -->"
    body = pending_body.sub('<!-- shaka:end -->') { "#{marker}\n<!-- shaka:end -->" }
    assert_refused_handoff(timing_env('pass').merge('PR_BODY' => body), 'Republish the rendering preview')
  end

  private

  def assert_refused_handoff(env, message, comments: [review_comment(CLEAN_OUTCOME)])
    with_policy('meaningful_changes') do |root, ref|
      _output, error, status = label(root, ref, comments:, env:)

      refute_predicate status, :success?
      assert_includes error, message
      refute_path_exists @label_file
      refute_path_exists "#{@label_file}.body"
    end
  end

  def timing_env(bucket)
    { 'PR_BODY' => pending_body, 'PR_CHECKS' => JSON.generate(checks(bucket)) }
  end

  def pending_body
    stats = { 'head' => HEAD, 'spend' => '$3.31', 't0' => '2026-11-11T00:03:00Z', 't1' => '2026-11-11T00:29:00Z' }
    <<~MARKDOWN
      Human introduction.
      <!-- shaka:begin -->
      **Estimated token costs:** $3.31 · ready pending
      <!-- shaka:stats #{JSON.generate(stats)} -->
      **This head:** Prompt to CI 26m · CI to ready pending · Ready to merged pending
      <!-- shaka:end -->
      Human footer.
    MARKDOWN
  end

  def checks(bucket)
    [{ 'name' => 'validate', 'state' => (bucket == 'pass' ? 'SUCCESS' : 'PENDING'),
       'bucket' => bucket, 'completedAt' => '2026-11-11T00:37:00Z' },
     { 'name' => 'claude-review', 'bucket' => 'pass', 'completedAt' => '2026-11-11T00:29:30Z' }]
  end
end

# The no-settings and first-setup paths leave out --ref, so no setting can excuse the review.
class CliAttentionWithoutSettingsTest < Minitest::Test
  include CliMergeFixture

  def test_no_review_needs_a_stated_reason
    with_repository('review' => review_policy('required' => 'none').except('ci_review_jobs')) do |root|
      FileUtils.mkdir_p(File.join(root, 'fake-bin'))
      File.write(File.join(root, 'fake-bin', 'gh'), CliAttentionReviewTest::FAKE, perm: 0o755)
      env = { 'PR_COMMENTS' => '[]', 'LABEL_FILE' => (written = File.join(root, 'label-written')) }
      _output, error, status = run_command('attention', 'owner/repo', '1', '--state', 'merge', root:, env:)

      refute_predicate status, :success?
      assert_includes error, '--review-waiver'
      refute_path_exists written
    end
  end
end
