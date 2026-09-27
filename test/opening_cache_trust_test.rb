# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'opening_check_test_helpers'
require_relative '../skills/shaka/lib/shaka/opening_check'

class OpeningCacheTrustTest < Minitest::Test
  include OpeningCheckTestHelpers

  def test_home_inside_checkout_cannot_supply_or_store_a_cached_verdict
    with_claude(parse('shaka merge', false)) do |root, trace|
      with_home(root) do
        assert_equal 'flagged', run_check(root).fetch('status')
        File.unlink(trace)
        assert_equal 'flagged', run_check(root).fetch('status')
        assert_path_exists trace
        refute_path_exists File.join(root, '.cache')
      end
    end
  end

  private

  def run_check(root)
    Shaka::OpeningCheck.new(summary: '`shaka merge` checks the head.', candidate_root: root,
                            reviewer: 'anthropic/claude').call
  end

  def with_home(root)
    original = Dir.method(:home)
    Dir.define_singleton_method(:home) { root }
    yield
  ensure
    Dir.define_singleton_method(:home, original)
  end
end
