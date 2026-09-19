require 'minitest/autorun'
require_relative '../lib/trail_marker'

class TrailMarkerTest < Minitest::Test
  def test_estimates_segment_time
    assert_equal '5.27.0', Gem.loaded_specs.fetch('minitest').version.to_s
    assert_equal 42, TrailMarker.minutes(3.5, 12)
  end
end
