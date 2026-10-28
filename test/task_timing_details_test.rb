# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/timings_details'

# Task timing must contribute equally to the expanded table and its collapsed totals.
class TaskTimingDetailsTest < Minitest::Test
  def test_task_start_includes_work_before_the_first_commit
    rendered = detail
    before = rendered['body'].lines.find { |line| line.start_with?('| Before the pull request |') }
    assert_equal '1h 0m', before.split('|')[4].strip
    assert_includes rendered['body'], '1h 30m between checkpoints'
    assert_equal 'Timings · 1h 30m between checkpoints', rendered['summary']
  end

  private

  def detail
    opened = Time.utc(2026, 10, 18, 8)
    data = { 'opened' => opened, 'first_commit' => opened - 300, 'merged' => opened + 1800,
             'task_started_at' => opened - 3600, 'labels' => [] }
    Shaka::TimingsDetails.new(data).detail
  end
end
