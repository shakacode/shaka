# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'claim_helpers'

class ClaimFailureTest < Minitest::Test
  include ClaimHelpers

  PR = { 'number' => 402, 'title' => 'Feedback', 'url' => 'https://github.com/shakacode/shaka/pull/402',
         'headRefName' => 'alex/400-fix', 'body' => '', 'closingIssuesReferences' => [] }.freeze

  def test_failed_github_and_remote_branch_commands_are_errors
    %w[gh git].each do |command|
      inner = runner(prs: [], branches: '')
      broken = lambda do |argv, **|
        argv.first == command ? ['', 'failure', ClaimHelpers::STATUS.new(1)] : inner.call(argv)
      end
      error = assert_raises(Shaka::Error) { subject(broken).result }
      assert_includes error.message, "#{command} "
    end
  end

  def test_a_missing_command_is_an_error
    broken = ->(*) { raise Errno::ENOENT }
    error = assert_raises(Shaka::Error) { subject(broken).result }
    assert_includes error.message, 'gh is unavailable'
  end

  def test_invalid_json_and_incomplete_metadata_are_errors
    ['not json', '{}', '[null]', JSON.generate([PR.except('body')]),
     JSON.generate([PR.merge('closingIssuesReferences' => [{}])])].each do |json|
      broken = ->(*) { [json, '', ClaimHelpers::STATUS.new(0)] }
      assert_raises(Shaka::Error) { subject(broken).result }
    end
  end

  def test_a_full_page_is_not_a_complete_ownership_check
    error = assert_raises(Shaka::Error) { claim('392', prs: Array.new(1000, PR), branches: '') }
    assert_includes error.message, 'ownership is incomplete'
  end

  def test_a_search_candidate_missing_from_the_inventory_is_a_blocking_error
    inner = runner(prs: [], branches: '')
    raced = lambda do |argv, **|
      next inner.call(argv) unless argv.include?('--search')

      [JSON.generate([{ 'number' => 402 }]), '', ClaimHelpers::STATUS.new(0)]
    end
    error = assert_raises(Shaka::Error) { subject(raced).result }
    assert_includes error.message, 'inventory changed'
  end

  private

  def subject(runner)
    Shaka::Claim.new(query: '392', root: Dir.pwd, runner: runner)
  end
end
