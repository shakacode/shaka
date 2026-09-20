# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'open3'

$LOAD_PATH.unshift File.expand_path('../skills/shaka/lib', __dir__)

module MetricAssert
  def assert_metric(haystack, label, *values)
    assert_includes haystack, "| #{label} | #{values.join(' | ')} |"
  end
end

module Minitest
  class Test
    include MetricAssert
  end
end
