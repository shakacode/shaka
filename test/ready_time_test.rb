# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/ready_time'

# A description update records when the head's gate turned green, whether or not a watch ever ran.
class ReadyTimeTest < Minitest::Test
  GREEN = '2026-10-26T19:19:00Z'
  GATE = { jobs: ['claude-review'], wait: 'one', seam_required_checks: nil }.freeze
  TIMELINE = { 'opened' => Time.utc(2026, 10, 26, 18) }.freeze

  # Answers the two check reads the gate needs, or fails like an unreachable GitHub.
  class FakeGitHub
    def initialize(rows, required: ['validate'], failure: nil)
      @rows = rows
      @required = required
      @failure = failure
    end

    def required_checks
      raise Shaka::Error, @failure if @failure

      @required.map { |name| { 'name' => name, 'bucket' => 'pass' } }
    end

    def configured_required_checks = []
    def checks = @rows
    def check_times = @rows
  end

  def row(name, completed = GREEN, bucket = 'pass') = { 'name' => name, 'bucket' => bucket, 'completedAt' => completed }

  def attach(github, gate = GATE) = Shaka::ReadyTime.attach(TIMELINE, github, gate)

  def test_a_green_gate_adds_its_time
    rows = [row('validate', '2026-10-26T19:00:00Z'), row('claude-review')]
    assert_equal Time.iso8601(GREEN), attach(FakeGitHub.new(rows))['ready_at']
  end

  def test_a_gate_that_is_not_green_adds_nothing
    assert_equal TIMELINE, attach(FakeGitHub.new([row('validate', GREEN, 'fail'), row('claude-review')]))
    assert_equal TIMELINE, attach(FakeGitHub.new([row('validate')]))
  end

  def test_checks_without_timestamps_add_nothing
    assert_equal TIMELINE, attach(FakeGitHub.new([row('validate', nil), row('claude-review', nil)]))
  end

  def test_a_failed_read_never_blocks_publication
    assert_equal TIMELINE, attach(FakeGitHub.new([], failure: 'offline'))
  end

  def test_unread_settings_add_nothing
    assert_equal TIMELINE, attach(FakeGitHub.new([row('validate')]), nil)
  end

  # Break: a task waiting for every review recorded the first review's time, which then outlasted the watch's.
  def test_a_task_override_keeps_the_stricter_wait
    config = Struct.new(:review, :merge).new({ 'ci_review_jobs' => %w[a b], 'ci_review_wait' => 'one' }, {})
    assert_equal 'all', Shaka::ReadyTime.gate(config, override: 'all')[:wait]
    assert_equal 'one', Shaka::ReadyTime.gate(config, override: 'none')[:wait]
    assert_equal 'one', Shaka::ReadyTime.gate(config)[:wait]
  end

  def test_the_gate_comes_from_the_trusted_settings
    config = Struct.new(:review, :merge).new({ 'ci_review_jobs' => ['claude-review'], 'ci_review_wait' => 'all' },
                                             { 'required_checks' => ['validate'] })
    assert_equal({ jobs: ['claude-review'], wait: 'all', seam_required_checks: ['validate'] },
                 Shaka::ReadyTime.gate(config))
    assert_nil Shaka::ReadyTime.gate(nil)
  end
end
