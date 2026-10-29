# frozen_string_literal: true

require_relative 'pr_watch_test'

# Under Auto the watcher also waits for checks outside the required set, as merge --auto refuses them.
class PrWatchAutoTest < Minitest::Test
  include PrWatchFixtures

  def test_auto_waits_for_a_pending_check_that_is_not_required
    frames = [frame(required: [check('validate', 'SUCCESS', 'pass')],
                    checks: [check('claude-review', 'SUCCESS', 'pass'), check('windows', 'PENDING', 'pending')]),
              frame(required: [check('validate', 'SUCCESS', 'pass')],
                    checks: [check('claude-review', 'SUCCESS', 'pass'), check('windows', 'SUCCESS', 'pass')])]

    assert_equal ['checks_terminal', 2], watch(frames, auto: true)
    assert_equal ['checks_terminal', 1], watch(frames, auto: false)
  end

  private

  def watch(frames, auto:)
    github = PrWatchTest::FakeGitHub.new(frames)
    now = 0
    sleeper = lambda do |seconds|
      now += seconds
      github.advance
    end
    adapters = { clock: -> { now }, sleeper:, comments: -> { comments_packet(frames.first) } }
    settings = { interval: 1, timeout: 10, settle: 1, auto: }
    [Shaka::PrWatch.new(github, head: HEAD, ci_jobs: ['claude-review'], settings:, adapters:).call, now]
  end
end
