# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# The merge command reads the merge-approved label before Auto's gates when --label-approval chose Auto,
# and merges under every Auto gate once a write-access account added it.
class CliMergeLabelApprovalTest < Minitest::Test
  include CliMergeFixture

  MARK = 'shaka:post-implementation'
  # Answers the label, checkpoint, and changed-file reads; every other call falls through to the merge fake.
  LABEL_GH = <<~RUBY_SCRIPT
    path = ARGV[1].to_s
    if ARGV[0, 2] == ['api', 'user']
      puts JSON.generate('login' => 'agent')
      exit 0
    elsif ARGV[0] == 'api' && path.start_with?('repos/owner/repo/issues/1/events?')
      puts(path.end_with?('page=1') ? ENV.fetch('LABEL_EVENTS') : '[]')
      exit 0
    elsif ARGV[0] == 'api' && path == "repos/owner/repo/collaborators/\#{ENV.fetch('LABELER')}/permission"
      puts JSON.generate('user' => { 'login' => ENV.fetch('LABELER') }, 'permission' => ENV.fetch('PERMISSION'))
      exit 0
    elsif ARGV[0] == 'api' && path.start_with?('repos/owner/repo/issues/1/comments?')
      puts(path.end_with?('page=1') ? ENV.fetch('CHECKPOINT_COMMENTS') : '[]')
      exit 0
    elsif ARGV[0] == 'api' && path.start_with?('repos/owner/repo/pulls/1/files?')
      puts JSON.generate(path.end_with?('page=1') ? [{ 'filename' => 'lib/fix.rb', 'status' => 'modified' }] : [])
      exit 0
    elsif ARGV[0, 2] == ['api', 'repos/owner/repo/pulls/1']
      puts JSON.generate('head' => { 'sha' => 'a' * 40 }, 'base' => { 'sha' => 'b' * 40 }, 'changed_files' => 1)
      exit 0
    end
  RUBY_SCRIPT

  def test_a_pr_without_the_label_is_handed_back_under_ask
    labeled('maint', 'write', labels: 'bug') do |_output, error, status, mutation|
      refute_predicate status, :success?
      assert_match(/merge-approved does not choose Auto: the PR does not carry it. Hand the PR back under Ask/, error)
      refute_path_exists mutation
    end
  end

  def test_a_writers_label_merges_under_auto_and_names_who_added_it
    labeled('maint', 'write') do |output, error, status, mutation|
      assert_predicate status, :success?, error
      assert_path_exists mutation
      assert_equal 'maint', JSON.parse(output).dig('merge_approval', 'labeled_by')
    end
  end

  def test_a_triage_label_is_refused_without_merging
    labeled('helper', 'read') do |_output, error, status, mutation|
      refute_predicate status, :success?
      assert_includes error, '"helper" added it without write access (read)'
      refute_path_exists mutation
    end
  end

  private

  # A trusted Ask repository whose PR carries merge-approved, added by labeler with permission.
  def labeled(labeler, permission, labels: 'merge-approved')
    with_merge_repository(merge_policy.merge('preference' => 'ask',
                                             'auto_merge_max_risk' => 'low')) do |root, ref, mutation|
      fake = File.join(root, 'fake-bin', 'gh')
      File.write(fake, File.read(fake).sub("require 'json'\n", "require 'json'\n#{LABEL_GH}"))
      event = { 'event' => 'labeled', 'actor' => { 'login' => labeler }, 'label' => { 'name' => 'merge-approved' },
                'created_at' => '2026-11-27T20:00:00Z' }
      env = { 'PR_LABELS' => labels, 'LABEL_EVENTS' => JSON.generate([event]), 'LABELER' => labeler,
              'PERMISSION' => permission, 'CHECKPOINT_COMMENTS' => JSON.generate([checkpoint]) }
      yield(*run_merge(root, ref, mutation, '--auto', '--label-approval', env:), mutation)
    end
  end

  def checkpoint
    body = "<!-- shaka:reply:post-implementation-abcdef0-0123abcd -->\nReport.\n" \
           "<!-- #{MARK}-risk low -->\n<!-- #{MARK}-adequacy adequate -->\n" \
           "<!-- #{MARK}-disposition Merge -->\n<!-- #{MARK} #{HEAD} ready -->\n"
    { 'id' => 1, 'user' => { 'login' => 'agent' }, 'body' => body, 'created_at' => '2026-11-07T00:00:00Z' }
  end
end
