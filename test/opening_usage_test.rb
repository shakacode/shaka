# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'opening_check_test_helpers'
require_relative '../skills/shaka/lib/shaka/opening_check'

class OpeningUsageTest < Minitest::Test
  include OpeningCheckTestHelpers

  def test_claude_opening_check_leaves_no_usage_file
    with_claude(parse('Pull requests', true)) do |root, _trace|
      with_tmpdir(File.dirname(root)) do
        assert_equal 'passed', check('Pull requests show the outcome.', root:).fetch('status')
        assert_empty Dir.glob(File.join(Dir.tmpdir, 'shaka-review-usage-*.json'))
      end
    end
  end

  private

  def with_tmpdir(path)
    original = ENV.fetch('TMPDIR', nil)
    ENV['TMPDIR'] = path
    yield
  ensure
    ENV['TMPDIR'] = original
  end
end
