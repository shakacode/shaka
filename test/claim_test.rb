# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'stringio'
require 'shaka/claim'

class ClaimTest < Minitest::Test
  STATUS = Struct.new(:exitstatus)
  PR_110 = { 'number' => 110, 'title' => 'Restore lines', 'url' => 'https://example/110',
             'headRefName' => 'jg-claude/36-restore-workflow-lines' }.freeze
  PR_111 = { 'number' => 111, 'title' => 'Dup', 'url' => 'https://example/111',
             'headRefName' => 'jg-codex/36-restore' }.freeze
  HEADS_36 = "aaa\trefs/heads/jg-claude/36-restore-workflow-lines\n" \
             "bbb\trefs/heads/jg-codex/36-restore-workflow-judgment\n" \
             "ccc\trefs/heads/jg-codex/136-unrelated\n"

  def test_reports_open_pull_requests_and_matching_remote_branches_as_a_collision
    result = claim('36', prs: [PR_110], branches: HEADS_36)

    assert result.fetch('collision')
    assert_equal 110, result.fetch('pull_requests').first.fetch('number')
    assert_equal %w[jg-claude/36-restore-workflow-lines jg-codex/36-restore-workflow-judgment],
                 result.fetch('branches')
  end

  def test_a_clear_search_is_not_a_collision
    result = claim('116', prs: [], branches: "aaa\trefs/heads/jg-cursor/115-walkthrough-pin-links\n")

    refute result.fetch('collision')
    assert_empty result.fetch('pull_requests')
    assert_empty result.fetch('branches')
  end

  def test_a_branch_prefix_hit_without_an_open_pr_is_still_a_collision
    result = claim('36', prs: [], branches: "aaa\trefs/heads/jg-cursor/36-restore-workflow-judgment\n")

    assert result.fetch('collision')
    assert_equal ['jg-cursor/36-restore-workflow-judgment'], result.fetch('branches')
  end

  def test_a_seam_template_matches_a_repository_specific_layout
    heads = "aaa\trefs/heads/feature/36/restore-lines\n" \
            "bbb\trefs/heads/feature/136/unrelated\n"
    result = claim('36', prs: [], branches: heads, branch_name: 'feature/{issue}/{description}')

    assert result.fetch('collision')
    assert_equal ['feature/36/restore-lines'], result.fetch('branches')
    assert_equal 'feature/{issue}/{description}', result.fetch('branch_name')
  end

  def test_refuses_a_non_numeric_work_item
    error = assert_raises(Shaka::Error) { claim('restore', prs: [], branches: '') }

    assert_includes error.message, 'positive integer'
  end

  def test_cli_prints_collision_json
    stdout, status = capture_cli(['36'], prs: [PR_111], branches: HEADS_36)

    assert_equal 0, status
    assert JSON.parse(stdout).fetch('collision')
  end

  private

  def claim(query, prs:, branches:, branch_name: nil)
    Shaka::Claim.new(query: query, root: Dir.pwd, runner: runner(prs: prs, branches: branches),
                     branch_name: branch_name).result
  end

  def capture_cli(arguments, prs:, branches:)
    stdout = StringIO.new
    original = $stdout
    $stdout = stdout
    status = Shaka::Claim.run(arguments, runner: runner(prs: prs, branches: branches))
    [stdout.string, status]
  ensure
    $stdout = original
  end

  def runner(prs:, branches:)
    lambda do |argv, **|
      return [JSON.generate(prs), '', STATUS.new(0)] if argv[1] == 'pr'
      return [branches, '', STATUS.new(0)] if argv[1] == 'ls-remote'

      raise "Unexpected command: #{argv.inspect}"
    end
  end
end
