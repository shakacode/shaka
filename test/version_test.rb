# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/version'

class VersionTest < Minitest::Test
  def test_stable_candidate_sorts_after_the_first_prerelease
    version = Gem::Version.new(Shaka::VERSION)

    refute_predicate version, :prerelease?
    assert_match(/\A1\.0\.\d+\z/, version.to_s)
    assert_operator version, :>, Gem::Version.new('0.1.0.pre.1')
    assert_operator version, :>, Gem::Version.new('0.0.999')
    refute_operator Gem::Version.new('0.0.1'), :>=, version
  end
end
