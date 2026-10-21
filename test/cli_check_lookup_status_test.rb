# frozen_string_literal: true

require_relative 'cli_merge_fixture'

# A failed check lookup names GitHub's HTTP status at the command boundary.
class CliCheckLookupStatusTest < Minitest::Test
  include CliMergeFixture

  def test_rate_limited_check_lookup_names_its_http_status_on_merge
    with_merge_repository do |root, ref, mutation|
      _, error, status = run_merge(root, ref, mutation, env: { 'RATE_LIMITED' => '1' })

      refute_predicate status, :success?
      assert_match(/HTTP 403/, error)
      refute_match(/rate limit exceeded/, error)
    end
  end

  def test_rate_limited_check_lookup_names_its_http_status_in_pr_status
    with_merge_repository do |root, ref, _|
      output, error, status = run_command('pr', 'owner/repo', '1', '--root', root, '--ref', ref,
                                          root:, env: { 'RATE_LIMITED' => '1' })

      assert_predicate status, :success?, error
      unavailable = JSON.parse(output).fetch('requiredChecksUnavailable')
      assert_match(/HTTP 403/, unavailable)
      refute_match(/rate limit exceeded/, unavailable)
    end
  end
end
