# frozen_string_literal: true

require_relative 'test_helper'
require 'rbconfig'

# bin/validate runs the tests under bundle exec, and every helper, fake gh, and reviewer
# stub a test starts is a Ruby process. Each one reloaded Bundler, which took most of its
# startup time and made local validation several times slower than the tests themselves.
class TestRubyChildrenTest < Minitest::Test
  def test_a_spawned_ruby_does_not_load_bundler
    skip 'Only a run under bundle exec has a Bundler environment to inherit' unless defined?(Bundler)

    output, status = Open3.capture2e(RbConfig.ruby, '-e', 'print defined?(Bundler).inspect')
    assert_predicate status, :success?, output

    assert_equal 'nil', output
  end
end
