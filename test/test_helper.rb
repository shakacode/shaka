# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'open3'

$LOAD_PATH.unshift File.expand_path('../skills/shaka/lib', __dir__)

module MetricAssert
  def assert_metric(haystack, label, *values)
    row = "| #{label} | #{values.join(' | ')} |"
    assert_match(/(?:^|\n)#{Regexp.escape(row)}(?:\n|\z)/, haystack)
  end
end

module BooleanAssert
  def assert_true(value, message = nil)
    assert_instance_of(TrueClass, value, message)
  end

  def assert_false(value, message = nil)
    assert_instance_of(FalseClass, value, message)
  end
end

module Minitest
  class Test
    include MetricAssert
    include BooleanAssert
  end
end
