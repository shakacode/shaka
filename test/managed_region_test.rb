# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/managed_region'

class ManagedRegionTest < Minitest::Test
  OPEN = Shaka::Publishing::OPEN_MARK
  CLOSE = Shaka::Publishing::CLOSE_MARK

  def test_no_region
    [nil, '', 'outside', OPEN, CLOSE].each do |body|
      assert_nil Shaka::Publishing.managed_region(body)
    end
  end

  def test_one_well_ordered_region
    assert_equal "\ninside\n", Shaka::Publishing.managed_region("before#{OPEN}\ninside\n#{CLOSE}after")
    assert_equal '', Shaka::Publishing.managed_region("#{OPEN}#{CLOSE}")
  end

  def test_duplicated_markers
    ["#{OPEN}#{OPEN}inside#{CLOSE}", "#{OPEN}inside#{CLOSE}#{CLOSE}"].each do |body|
      assert_nil Shaka::Publishing.managed_region(body)
    end
  end

  def test_reversed_markers
    assert_nil Shaka::Publishing.managed_region("#{CLOSE}inside#{OPEN}")
  end

  def test_crlf_is_preserved
    assert_equal "\r\ninside\r\n", Shaka::Publishing.managed_region("#{OPEN}\r\ninside\r\n#{CLOSE}")
  end
end
