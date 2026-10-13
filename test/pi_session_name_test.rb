# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'

class PiSessionNameTest < Minitest::Test
  def test_pi_extension_behavior
    root = File.expand_path('..', __dir__)
    output, error, status = Open3.capture3('node', '--test', 'test/pi_session_name_test.mjs', chdir: root)

    assert_predicate status, :success?, "#{output}\n#{error}"
  end
end
