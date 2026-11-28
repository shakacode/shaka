# frozen_string_literal: true

require_relative 'cursor_usage_refresh_test'

# The refresh changes only usage, so an example published earlier without its backticks cannot stop it.
class CursorUsageRefreshExamplesTest < Minitest::Test
  include CursorUsageRefreshFixture

  LOST = 'Such as ```js``` blocks.'

  def test_a_lost_example_in_published_prose_does_not_stop_the_refresh
    Dir.mktmpdir do |directory|
      usage = JSON.parse(empty_usage(directory))
      log = File.join(directory, 'gh.log')
      bind_pull_request(directory, usage)
      pull = published_pull(usage)
      pull['body'] = pull['body'].sub('A summary.', LOST)
      _out, err, status = run_hook(hook_env(directory, pull, log))

      assert_predicate status, :success?, err
      assert_includes patched_body(log), LOST
    end
  end
end
