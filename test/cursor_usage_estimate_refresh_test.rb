# frozen_string_literal: true

require_relative 'cursor_usage_refresh_test'
require 'cgi'

PENDING_LINE = 'AI spend UNKNOWN · Prompt to CI UNKNOWN · CI to ready pending · Ready to merged pending'

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
      refute_includes patched_body(log), 'shaka:rendering-preview'
    end
  end

  private

  def published_metrics_pull(usage)
    pull = published_pull(usage)
    stats = "<!-- shaka:stats {\"spend\":\"UNKNOWN\"} -->\n#{PENDING_LINE}\n"
    pull['body'] = pull['body'].sub("<!-- shaka:begin -->\n", "<!-- shaka:begin -->\n#{stats}")
    pull['body'] = pull['body'].sub("<details>\n<summary>Usage and cost",
                                    "<!-- shaka:estimated-cost -->\n**Estimated cost:** UNKNOWN\n\n" \
                                    "<details>\n<summary>Shaka metrics</summary>\n\n<details>\n<summary>Usage and cost")
    marker = "<!-- shaka:rendering-preview #{'a' * 40} -->"
    pull['body'] = pull['body'].sub('<!-- shaka:end -->', "</details>\n#{marker}\n<!-- shaka:end -->")
    pull
  end

  def assert_visible_estimate(updated)
    estimate = updated[/\*\*Estimated token costs:\*\* ([^\n]+)/, 1]
    refute_nil estimate
    assert_includes updated, "AI spend #{CGI.unescapeHTML(estimate)}"
    assert_includes updated, '<summary>Usage and cost</summary>'
    refute_includes updated, 'Usage and cost ·'
    assert_includes updated, '<summary>Shaka metrics</summary>'
  end
end
