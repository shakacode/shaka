# frozen_string_literal: true

require_relative 'github_helper'
require 'shaka/publication/feature_guard'

class FeaturePublicationTest < Minitest::Test
  include GitHubHelper

  def test_paginated_configuration_rename_is_blocked
    first = Array.new(100) { |index| { 'filename' => "feature#{index}.rb" } }
    last = [{ 'filename' => 'renamed', 'previous_filename' => '.agents/shaka/secret' }]
    github = client(response(first), response(last))
    error = assert_raises(Shaka::Error) do
      Shaka::FeaturePublication.check(github:, pull: { 'changed_files' => 101 }, flow: 'feature')
    end
    refute_includes error.message, 'secret'
    assert_equal 2, @calls.size
  end

  def test_incomplete_unknown_or_malformed_file_lists_fail_closed
    [nil, 2, 3001].each do |count|
      github = client(response([{ 'filename' => 'feature.rb' }]))
      assert_raises(Shaka::Error) do
        Shaka::FeaturePublication.check(github:, pull: { 'changed_files' => count }, flow: 'feature')
      end
    end
    github = client(response([{ 'filename' => nil }]))
    assert_raises(Shaka::Error) do
      Shaka::FeaturePublication.check(github:, pull: { 'changed_files' => 1 }, flow: 'feature')
    end
  end
end
