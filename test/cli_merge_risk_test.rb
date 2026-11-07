# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# The merge command applies merge.auto_merge: low through the real wiring: this account's checkpoint marker
# for the exact head, the trusted high-risk areas, and the PR's changed files from GitHub.
class CliMergeRiskTest < Minitest::Test
  include CliMergeFixture

  MARK = 'shaka:post-implementation'
  # Answers the reads the risk gate adds; every other call falls through to the merge fixture's fake.
  RISK_GH = <<~RUBY_SCRIPT
    if ARGV[0, 2] == ['api', 'user']
      puts JSON.generate('login' => 'agent')
      exit 0
    elsif ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/issues/1/comments?')
      rows = ARGV[1].end_with?('page=1') ? JSON.parse(ENV.fetch('CHECKPOINT_COMMENTS')) : []
      puts JSON.generate(rows)
      exit 0
    elsif ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/pulls/1/files?')
      names = ENV.fetch('PR_FILES').split(',')
      rows = ARGV[1].end_with?('page=1') ? names.map { |name| { 'filename' => name, 'status' => 'modified' } } : []
      puts JSON.generate(rows)
      exit 0
    elsif ARGV[0, 2] == ['api', 'repos/owner/repo/pulls/1']
      puts JSON.generate('head' => { 'sha' => 'a' * 40 }, 'base' => { 'sha' => 'b' * 40 },
                         'changed_files' => ENV.fetch('PR_FILES').split(',').length)
      exit 0
    end
  RUBY_SCRIPT

  def test_a_low_rating_outside_every_area_merges
    merged('low', 'lib/fix.rb') { |error, status, mutation| assert_merged(error, status, mutation) }
  end

  def test_a_medium_rating_goes_to_a_person
    merged('medium', 'lib/fix.rb') do |error, status, mutation|
      assert_refused(error, status, mutation, 'the checkpoint rates this head medium risk')
    end
  end

  def test_a_high_risk_area_goes_to_a_person_whatever_the_rating
    merged('low', 'db/migrate/1_add_index.rb') do |error, status, mutation|
      assert_refused(error, status, mutation, 'db/migrate/1_add_index.rb is in high-risk area database')
    end
  end

  def test_a_rating_for_another_head_or_account_does_not_count
    merged('low', 'lib/fix.rb', head: 'c' * 40) do |error, status, mutation|
      assert_refused(error, status, mutation, 'the checkpoint for this head has no risk rating')
    end
    merged('low', 'lib/fix.rb', login: 'someone-else') do |error, status, mutation|
      assert_refused(error, status, mutation, 'the checkpoint for this head has no risk rating')
    end
  end

  def test_a_confirmed_head_merges_whatever_the_rating
    merged('high', 'db/migrate/1_add_index.rb', '--limits-confirmed-head', HEAD) do |error, status, mutation|
      assert_merged(error, status, mutation)
    end
  end

  private

  def merged(rating, files, *extra, head: HEAD, login: 'agent')
    with_merge_repository(merge_policy.merge('preference' => 'auto', 'auto_merge' => 'low')) do |root, ref, mutation|
      fake = File.join(root, 'fake-bin', 'gh')
      File.write(fake, File.read(fake).sub("require 'json'\n", "require 'json'\n#{RISK_GH}"))
      env = { 'PR_FILES' => files, 'CHECKPOINT_COMMENTS' => JSON.generate([checkpoint(rating, head, login)]) }
      _, error, status = run_merge(root, ref, mutation, *extra, env:)
      yield error, status, mutation
    end
  end

  def checkpoint(rating, head, login)
    body = "<!-- shaka:reply:post-implementation-abcdef0-0123abcd -->\nReport.\n" \
           "<!-- #{MARK}-risk #{rating} -->\n<!-- #{MARK}-adequacy adequate -->\n" \
           "<!-- #{MARK}-disposition Merge -->\n<!-- #{MARK} #{head} ready -->\n"
    { 'id' => 1, 'user' => { 'login' => login }, 'body' => body, 'created_at' => '2026-11-07T00:00:00Z' }
  end

  def assert_merged(error, status, mutation)
    assert_predicate status, :success?, error
    assert_path_exists mutation
  end

  def assert_refused(error, status, mutation, reason)
    refute_predicate status, :success?
    assert_includes error, "#{reason}, and merge.auto_merge: low lets the agent merge only low risk"
    refute_path_exists mutation
  end
end
