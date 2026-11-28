# frozen_string_literal: true

require_relative 'private_setup_test'
require_relative 'cli_merge_risk_test'

# Individual settings grant merge no policy, but their merge.hold_labels still stop a merge: local settings may
# add merge gates, never remove them, so the shipped `hold` keeps working too (issue #1324).
class CliMergeIndividualHoldTest < Minitest::Test
  include PrivateSetupFixture
  include CliMergeFixture

  # Handoff reads the PR's labels through the issues API; every other call falls through to the merge fakes.
  LABELS_GH = <<~RUBY_SCRIPT
    if ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/issues/1/labels?')
      names = ARGV[1].end_with?('page=1') ? ENV.fetch('PR_LABELS').split(',') : []
      puts JSON.generate(names.map { |name| { 'name' => name } })
      exit 0
    end
  RUBY_SCRIPT

  def test_an_individual_hold_label_refuses_the_merge
    individual_merge('Do-Not-Merge') do |error, status, mutation|
      refute_predicate status, :success?
      assert_match(/hold label "Do-Not-Merge" \(merge\.hold_labels\)/, error)
      refute_path_exists mutation
    end
  end

  def test_the_shipped_hold_label_still_refuses_the_merge
    individual_merge('hold') do |error, status, mutation|
      refute_predicate status, :success?
      assert_match(/hold label "hold" \(merge\.hold_labels\)/, error)
      refute_path_exists mutation
    end
  end

  def test_an_unlisted_label_merges
    individual_merge('bug') do |error, status, mutation|
      assert_predicate status, :success?, error
      assert_path_exists mutation
    end
  end

  def test_handoff_reports_both_hold_labels
    %w[hold do-not-merge].each do |label|
      individual_setup do |repo, ref|
        env = { 'PR_LABELS' => label, 'PR_FILES' => 'lib/fix.rb', 'CHECKPOINT_COMMENTS' => '[]' }
        output, error, = run_command('handoff', 'owner/repo', '1', '--root', repo, '--ref', ref, '--head', HEAD,
                                     root: repo, env:)
        assert_includes output, "held by #{label}", error
      end
    end
  end

  private

  def individual_merge(label)
    individual_setup do |repo, ref|
      mutation = File.join(repo, 'mutation.json')
      checkpoint = CliMergeRiskTest.allocate.send(:checkpoint, 'low', HEAD, 'agent')
      env = { 'PR_LABELS' => label, 'PR_FILES' => 'lib/fix.rb', 'CHECKPOINT_COMMENTS' => JSON.generate([checkpoint]) }
      _, error, status = run_merge(repo, ref, mutation, *CONFIRMED, '--review-waiver', 'individual hold test', env:)
      yield error, status, mutation
    end
  end

  def individual_setup
    with_setup do |repo, ref|
      setup_private(repo, ref)
      path = config_path(repo)
      File.write(path, File.read(path).sub(/^merge:\n/, "merge:\n  hold_labels: [do-not-merge]\n"))
      install_fake_github(repo)
      fake = File.join(repo, 'fake-bin', 'gh')
      File.write(fake, File.read(fake).sub("require 'json'\n", "require 'json'\n#{CliMergeRiskTest::RISK_GH}#{LABELS_GH}"))
      File.write(File.join(repo, 'message.json'), JSON.generate('title' => 'Fix', 'body' => 'Reason.'))
      yield repo, ref
    end
  end
end
