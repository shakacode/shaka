# frozen_string_literal: true

require_relative 'cursor_usage_refresh_test'
require 'cgi'

# A stop hook must update the visible total alongside the nested usage report.
class CursorUsageEstimateRefreshTest < Minitest::Test
  include CursorUsageRefreshFixture

  def test_stop_hook_refreshes_the_visible_estimate_outside_shaka_metrics
    Dir.mktmpdir do |directory|
      usage = JSON.parse(empty_usage(directory))
      log = File.join(directory, 'gh.log')
      bind_pull_request(directory, usage)
      pull = published_metrics_pull(usage)
      _out, err, status = run_hook(hook_env(directory, pull, log))
      assert_predicate status, :success?, err
      assert_visible_estimate(patched_body(log))
    end
  end

  private

  def published_metrics_pull(usage)
    pull = published_pull(usage)
    pull['body'] = pull['body'].sub("<details>\n<summary>Usage and cost",
                                    "<!-- shaka:estimated-cost -->\n**Estimated cost:** UNKNOWN\n\n" \
                                    "<details>\n<summary>Shaka metrics</summary>\n\n<details>\n<summary>Usage and cost")
    pull['body'] = pull['body'].sub('<!-- shaka:end -->', "</details>\n<!-- shaka:end -->")
    pull
  end

  def assert_visible_estimate(updated)
    estimate = updated[%r{<summary>Usage and cost · (.+) estimated</summary>}, 1]
    refute_nil estimate
    assert_includes updated, "**Estimated token costs:** #{CGI.unescapeHTML(estimate)}"
    assert_includes updated, '<summary>Shaka metrics</summary>'
  end
end
