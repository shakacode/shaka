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

  def test_type_changes_keep_the_added_entry_in_either_api_order
    added = { 'filename' => 'policy.md', 'status' => 'added' }
    removed = { 'filename' => 'policy.md', 'status' => 'removed' }
    [[removed, added], [added, removed]].each do |entries|
      assert_equal [added], Shaka::FeaturePublication.files(client(response(entries)), { 'changed_files' => 1 })
    end
  end

  def test_type_changes_cannot_hide_configuration_paths
    entries = [{ 'filename' => '.agents/shaka/config.yml', 'status' => 'removed' },
               { 'filename' => '.agents/shaka/config.yml', 'status' => 'added' }]
    github = client(response(entries))
    error = assert_raises(Shaka::Error) do
      Shaka::FeaturePublication.check(github:, pull: { 'changed_files' => 1 }, flow: 'feature')
    end
    assert_includes error.message, 'Feature PR contains Shaka configuration changes'
  end

  def test_incomplete_type_change_list_fails_closed
    entries = [{ 'filename' => 'policy.md', 'status' => 'removed' },
               { 'filename' => 'policy.md', 'status' => 'added' }]
    assert_raises(Shaka::Error) do
      Shaka::FeaturePublication.files(client(response(entries)), { 'changed_files' => 2 })
    end
  end

  def test_unexplained_duplicate_paths_fail_closed
    [
      [{ 'filename' => 'policy.md', 'status' => 'added' }, { 'filename' => 'policy.md', 'status' => 'added' }],
      [{ 'filename' => 'policy.md' }, { 'filename' => 'policy.md' }],
      [{ 'filename' => 'policy.md', 'status' => 'removed', 'previous_filename' => '.agents/shaka/config.yml' },
       { 'filename' => 'policy.md', 'status' => 'added' }]
    ].each do |entries|
      assert_raises(Shaka::Error) do
        Shaka::FeaturePublication.files(client(response(entries)), { 'changed_files' => 1 })
      end
    end
  end
end
