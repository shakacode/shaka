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
        retargeted = change == 'retarget_gate' && count >= 3
      retargeted ||= File.exist?("#{ENV.fetch('LABEL_FILE')}.retargeted")
      pull['baseRefName'] = 'release' if retargeted
      pull['headRefOid'] = 'b' * 40 if File.exist?("#{ENV.fetch('LABEL_FILE')}.moved")
      end
      puts JSON.generate('data' => { 'repository' => { 'pullRequest' => pull } })
    elsif ARGV[0, 2] == %w[pr checks]
      rows = JSON.parse(ENV.fetch('PR_CHECKS', '[]'))
      if File.exist?("#{ENV.fetch('LABEL_FILE')}.rerun")
        rows.each { |row| row.update('state' => 'PENDING', 'bucket' => 'pending') }
      end
      rows.select! { |row| row['name'] == 'validate' } if ARGV.include?('--required')
      puts JSON.generate(rows)
    elsif path.start_with?('repos/owner/repo/rules/branches/main')
      puts '[]'
    elsif path == 'user'
      puts JSON.generate('login' => 'shaka-agent')
    elsif path.include?('/issues/1/comments')
      File.write("#{ENV.fetch('LABEL_FILE')}.rerun", '') if ENV['PR_CHANGE'] == 'rerun'
      puts ENV.fetch('PR_COMMENTS', '[]')
    elsif path.include?('/issues/1/labels') && ARGV.include?('POST')
      File.write(ENV.fetch('LABEL_FILE'), 'labeled')
      puts '[]'
    elsif path.include?('/issues/1/labels')
      File.write("#{ENV.fetch('LABEL_FILE')}.deleted", '') if ARGV.include?('DELETE')
      if ENV['PR_CHANGE'] == 'retarget_labels'
        File.write("#{ENV.fetch('LABEL_FILE')}.retargeted", '')
        puts JSON.generate([{ 'name' => 'awaiting-resume' }])
      else
        File.write("#{ENV.fetch('LABEL_FILE')}.moved", '') if ENV['PR_CHANGE'] == 'head_labels'
        puts '[]'
      end
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

class CliAttentionGateTest < Minitest::Test
  include CliAttentionFixture

  def test_merge_handoff_waits_for_required_ci
    assert_refused_handoff(check_env('PENDING', 'pending'), 'Required check is not passing')
  end

  def test_merge_handoff_applies_the_label_after_required_ci_passes
    with_policy('meaningful_changes') do |root, ref|
      _output, error, status = label(root, ref, comments: [review_comment(CLEAN_OUTCOME)],
                                                env: check_env('SUCCESS', 'pass'))

      assert_predicate status, :success?, error
      assert_path_exists @label_file
    end
  end

  def test_merge_handoff_refuses_a_closed_snapshot_even_if_the_pr_reopens
    assert_refused_handoff({ 'PR_CHANGE' => 'reopen' }, 'Pull request is not open.', comments: [])
  end

  def test_merge_handoff_refuses_a_retarget_while_reading_the_gate
    assert_refused_handoff({ 'PR_CHANGE' => 'retarget_gate' }, 'PR base changed')
  end

  def test_merge_handoff_refuses_a_retarget_before_labeling
    assert_refused_handoff({ 'PR_CHANGE' => 'retarget_labels' }, 'PR base changed')
    refute_path_exists "#{@label_file}.deleted"
  end

  def test_merge_handoff_reads_required_ci_after_local_review
    env = check_env('SUCCESS', 'pass').merge('PR_CHANGE' => 'rerun')
    assert_refused_handoff(env, 'Required check is not passing')
  end

  def test_merge_handoff_refuses_a_moved_head_before_labeling
    assert_refused_handoff({ 'PR_CHANGE' => 'head_labels' }, 'PR head changed')
  end

  private

  def check_env(state, bucket)
    checks = [{ 'name' => 'validate', 'state' => state, 'bucket' => bucket }]
    { 'PR_CHECKS' => JSON.generate(checks) }
  end

  def assert_refused_handoff(env, message, comments: [review_comment(CLEAN_OUTCOME)])
    with_policy('meaningful_changes') do |root, ref|
      _output, error, status = label(root, ref, comments:, env:)

      refute_predicate status, :success?
      assert_includes error, message
      refute_path_exists @label_file
    end
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
