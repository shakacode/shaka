# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/publication/timings_details'

# The bars put a pull request's stretches and steps on one axis without hiding work or failures.
class TimingBarsTest < Minitest::Test
  OPENED = Time.utc(2026, 10, 18, 8, 0)

  def step(command, minute, seconds, **extra)
    { 'id' => format('%016x', (minute * 1000) + seconds), 'command' => command, 'exit' => 0,
      'at' => (OPENED + (minute * 60)).iso8601, 'duration_ms' => seconds * 1000 }.merge(extra.transform_keys(&:to_s))
  end

  def validation(minute, seconds, exit: 0) = step('evidence run', minute, seconds, exit:, check: 'validate')
  def review(minute, seconds, provider) = step('review run', minute, seconds, provider:)

  def row(from, to, wait: false) = { name: 'x', from: OPENED + (from * 60), to: OPENED + (to * 60), ending: nil, wait: }

  def lanes(rows, steps, zone = 'UTC')
    chart = Shaka::TimingBars.new(rows, steps, zone).render
    lines = chart.lines(chomp: true)[2..].take_while { |line| !line.empty? }
    lines.to_h { |line| [line[/\A\D+?(?=\s{2})/], line] }
  end

  def test_reviewers_that_ran_together_get_their_own_lanes_starting_in_the_same_column
    bars = lanes([row(0, 60)], [review(10, 300, 'openai'), review(10, 300, 'anthropic')])

    assert_equal bars['Review openai'].index('#'), bars['Review anthropic'].index('#')
    assert_equal %w[PR], bars.keys.first(1)
  end

  def test_lanes_run_validation_then_reviews_then_checkpoint
    steps = [step('post-implementation run', 50, 30), review(20, 60, 'openai'), validation(5, 600)]

    assert_equal ['PR', 'Validation', 'Review openai', 'Checkpoint'], lanes([row(0, 60)], steps).keys
  end

  def test_a_long_idle_wait_is_cut_visibly_on_every_lane_and_says_how_much
    rows = [row(0, 30), row(30, 1200, wait: true), row(1200, 1230)]
    bars = lanes(rows, [validation(5, 600), validation(1205, 600)])

    assert_includes bars['PR'], '//19h//'
    assert_includes bars['Validation'], '//'
    assert_operator bars['Validation'].count('#'), :>=, 20
    assert_includes Shaka::TimingBars.new(rows, [], 'UTC').render, '// idle wait cut'
  end

  def test_a_short_wait_stays_to_scale_and_needs_no_cut_key
    chart = Shaka::TimingBars.new([row(0, 55), row(55, 60, wait: true)], [], 'UTC').render

    refute_includes chart, '//'
    assert_match(/=+\.+$/, chart)
  end

  # A cut may not swallow a run, however long the wait around it is.
  def test_a_step_running_during_a_wait_stays_drawn_and_only_the_idle_part_is_cut
    rows = [row(0, 10), row(10, 1000, wait: true)]
    bars = lanes(rows, [validation(500, 600)])

    assert_operator bars['Validation'].count('#'), :>=, 1
    assert_equal 2, bars['PR'].scan(%r{//\d+h//}).size
  end

  def test_a_one_minute_wait_and_a_short_failure_stay_visible_beside_longer_runs
    rows = [row(0, 600), row(600, 601, wait: true), row(601, 1200)]
    bars = lanes(rows, [validation(100, 6000), validation(150, 1, exit: 1)])

    assert_includes bars['PR'], '.'
    assert_includes bars['Validation'], 'x'
  end

  def test_a_wait_filling_the_whole_timeline_is_drawn_without_dividing_by_zero
    chart = Shaka::TimingBars.new([row(0, 600, wait: true)], [], 'UTC').render

    assert_match(/^PR\s+\.{60}$/, chart)
  end

  def test_nothing_to_draw_returns_nil
    assert_nil Shaka::TimingBars.new([], [], 'UTC').render
    assert_nil Shaka::TimingBars.new([row(5, 5)], [], 'UTC').render
  end

  # Three waits of a third each are the most the axis can cut, and they still fit the width.
  def test_every_line_stays_inside_the_width_with_several_cuts
    chart = Shaka::TimingBars.new(three_long_waits, [validation(1, 60)], 'UTC').render

    assert_operator chart.lines(chomp: true)[1..-4].map(&:size).max, :<=, 12 + Shaka::TimingBars::WIDTH
    assert_equal 3, chart[/^PR.*$/].scan(%r{//\d+h//}).size
  end

  def three_long_waits
    (0..2).flat_map { |n| [row(n * 1000, (n * 1000) + 5), row((n * 1000) + 5, (n + 1) * 1000, wait: true)] }
  end

  def test_a_retry_that_passed_in_the_same_cell_does_not_read_failed
    bars = lanes([row(0, 600)], [validation(100, 2, exit: 1), validation(100, 40)])

    refute_includes bars['Validation'], 'x'
  end

  def test_the_header_reads_in_the_chosen_zone_and_names_it
    skip 'this machine has no zone data' unless File.directory?(Shaka::TimeZone.database)

    chart = Shaka::TimingBars.new([row(0, 60)], [], 'America/Los_Angeles').render

    assert_match(/10-18 01:00\s+10-18 02:00 PDT/, chart)
  end

  def test_the_chart_is_plain_ascii_inside_one_fence
    chart = Shaka::TimingBars.new([row(0, 60)], [review(5, 60, 'openai')], 'UTC').render

    assert_predicate chart, :ascii_only?
    assert_equal 2, chart.scan('```').size
  end
end
