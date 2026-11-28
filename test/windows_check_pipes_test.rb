# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/evidence/windows_check'

# A check whose last pipe cannot be created closes every pipe it already opened and starts nothing.
class WindowsCheckPipesTest < Minitest::Test
  def test_a_failed_last_pipe_closes_the_earlier_ones
    [false, true].each do |input|
      opened = with_failing_last_pipe(input ? 3 : 2) do
        assert_raises(Errno::EMFILE) { Shaka::Evidence::WindowsCheck.new(%w[ruby -e exit], root: Dir.pwd, input:) }
      end

      assert opened.all?(&:closed?), "input: #{input} left a pipe open"
    end
  end

  private

  def with_failing_last_pipe(calls)
    opened = []
    original = IO.method(:pipe)
    IO.define_singleton_method(:pipe) do
      raise Errno::EMFILE if opened.size / 2 == calls - 1

      original.call.tap { |pair| opened.concat(pair) }
    end
    yield
    opened
  ensure
    IO.define_singleton_method(:pipe, original)
  end
end
